job "mediawiki" {
  datacenters = ["dc1"]

  # The update stanza specified at the job level will apply to all groups within the job
  update {
    max_parallel = 1
    health_check = "checks"
    auto_revert  = false
    auto_promote = true
    # canary count equal to the desired count allows a Nomad job to model blue/green deployments
    canary       = 1
  }

  group "http" {
    task "http" {
      driver = "docker"

      config {
        image   = "ghcr.io/femiwiki/mediawiki:latest"
        command = "caddy"
        args    = ["run"]

        # Mount volumes into the container
        # Reference: https://www.nomadproject.io/docs/drivers/docker#mounts
        mounts = [
          {
            type     = "volume"
            target   = "/etc/caddycerts"
            source   = "caddy"
            readonly = false
          }
        ]

        volumes = [
          # Overwrite production Caddyfile
          "local/Caddyfile:/srv/femiwiki.com/Caddyfile"
        ]

        memory_hard_limit = 400
      }

      resources {
        memory = 80
      }

      template {
        data = <<EOF
{
  # Global options
  auto_https off
}
*:80
root * /srv/femiwiki.com
php_fastcgi {$NOMAD_UPSTREAM_ADDR_fastcgi}
file_server
encode gzip
header {
  # Enable XSS filtering for legacy browsers
  X-XSS-Protection "1; mode=block"
  # Block content sniffing, and enable Cross-Origin Read Blocking
  X-Content-Type-Options "nosniff"
  # Avoid clickjacking
  X-Frame-Options "DENY"
}
rewrite /w/api.php /api.php
rewrite /w/* /index.php

# Proxy requests to RESTBase
# Reference:
#   https://www.mediawiki.org/wiki/RESTBase/Installation#Proxy_requests_to_RESTBase_from_your_webserver
reverse_proxy /localhost/* {$NOMAD_UPSTREAM_ADDR_restbase}
EOF

        destination = "local/Caddyfile"
      }
    }

    network {
      mode = "bridge"

      port "http" {
        static = 80
        to     = 80
      }

      port "https" {
        static = 443
        to     = 443
      }
    }

    service {
      name = "http"
      port = "80"

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "fastcgi"
              local_bind_port  = 9000
            }

            upstreams {
              destination_name = "restbase"
              local_bind_port  = 7231
            }
          }
        }

        sidecar_task {
          config {
            memory_hard_limit = 500
          }
          resources {
            memory = 300
          }
        }
      }
    }
  }

  group "fastcgi" {
    volume "configs" {
      type      = "host"
      source    = "configs"
      read_only = true
    }

    task "fastcgi" {
      driver = "docker"

      config {
        image = "ghcr.io/femiwiki/mediawiki:latest"
        memory_hard_limit = 600
      }

      env {
        FEMIWIKI_DEBUG_MODE = "localhost"
      }

      resources {
        memory = 300
      }

      volume_mount {
        volume      = "configs"
        destination = "/a"
        read_only   = true
      }
    }

    network {
      mode = "bridge"
    }

    service {
      name = "fastcgi"
      port = "9000"

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "mysql"
              local_bind_port  = 3306
            }

            upstreams {
              destination_name = "memcached"
              local_bind_port  = 11211
            }

            upstreams {
              destination_name = "parsoid"
              local_bind_port  = 8000
            }

            upstreams {
              destination_name = "restbase"
              local_bind_port  = 7231
            }

            upstreams {
              destination_name = "mathoid"
              local_bind_port  = 10044
            }
          }
        }

        sidecar_task {
          config {
            memory_hard_limit = 300
          }
          resources {
            memory = 32
          }
        }
      }
    }
  }

  group "mysql" {
    task "mysql" {
      driver = "docker"

      config {
        image = "mysql:8.0"
        args  = ["--default-authentication-plugin=mysql_native_password"]
        memory_hard_limit = 1000
      }

      resources {
        memory = 500
      }

      env {
        MYSQL_ROOT_PASSWORD = "localfemiwikipassword"
        MYSQL_DATABASE      = "femiwiki"
        MYSQL_USER          = "DB_USERNAME" // secret.php.example에 적힌 기본값
        MYSQL_PASSWORD      = "DB_PASSWORD" // secret.php.example에 적힌 기본값
      }
    }

    network {
      mode = "bridge"
    }

    service {
      name = "mysql"
      port = "3306"

      connect {
        sidecar_service {}

        sidecar_task {
          config {
            memory_hard_limit = 300
          }
          resources {
            memory = 30
          }
        }
      }
    }
  }

  group "memcached" {
    task "memcached" {
      driver = "docker"

      config {
        image = "memcached:1-alpine"
        memory_hard_limit = 240
      }

      resources {
        memory = 60
      }
    }

    network {
      mode = "bridge"
    }

    service {
      name = "memcached"
      port = "11211"

      connect {
        sidecar_service {}

        sidecar_task {
          config {
            memory_hard_limit = 300
          }
          resources {
            memory = 30
          }
        }
      }
    }
  }

  group "parsoid" {
    task "parsoid" {
      driver = "docker"

      config {
        image = "ghcr.io/femiwiki/parsoid:latest"
        memory_hard_limit = 400
      }

      resources {
        memory = 120
      }

      env {
        MEDIAWIKI_LINTING     = "true"
        MEDIAWIKI_APIS_DOMAIN = "localhost"
        # Avoid using NOMAD_UPSTREAM_ADDR_http https://github.com/femiwiki/nomad/issues/1
        MEDIAWIKI_APIS_URI    = "http://localhost/api.php"
      }
    }

    network {
      mode = "bridge"
    }

    service {
      name = "parsoid"
      port = "8000"

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "http"
              local_bind_port  = 80
            }
          }
        }

        sidecar_task {
          config {
            memory_hard_limit = 300
          }
          resources {
            memory = 30
          }
        }
      }
    }
  }

  group "restbase" {
    task "restbase" {
      driver = "docker"

      config {
        image = "ghcr.io/femiwiki/restbase:latest"
        memory_hard_limit = 400
      }

      resources {
        memory = 100
      }

      env {
        # Avoid using NOMAD_UPSTREAM_ADDR_http https://github.com/femiwiki/nomad/issues/1
        MEDIAWIKI_APIS_URI    = "http://localhost/api.php"
        MEDIAWIKI_APIS_DOMAIN = "localhost"
        PARSOID_URI           = "http://${NOMAD_UPSTREAM_ADDR_parsoid}"
        MATHOID_URI           = "http://${NOMAD_UPSTREAM_ADDR_mathoid}"
      }
    }

    network {
      mode = "bridge"
    }

    service {
      name = "restbase"
      port = "7231"


      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "http"
              local_bind_port  = 80
            }

            upstreams {
              destination_name = "parsoid"
              local_bind_port  = 8000
            }

            upstreams {
              destination_name = "mathoid"
              local_bind_port  = 10044
            }
          }
        }

        sidecar_task {
          config {
            memory_hard_limit = 300
          }
          resources {
            memory = 30
          }
        }
      }
    }
  }

  group "mathoid" {
    task "mathoid" {
      driver = "docker"

      config {
        image = "ghcr.io/femiwiki/mathoid:latest"
        memory_hard_limit = 600
      }

      resources {
        memory = 150
      }

      env {
        # Amazon EC2 t3a-small has two vCPUs
        MATHOID_NUM_WORKERS = "2"
      }
    }

    network {
      mode = "bridge"
    }

    service {
      name = "mathoid"
      port = "10044"

      connect {
        sidecar_service {}

        sidecar_task {
          config {
            memory_hard_limit = 300
          }
          resources {
            memory = 30
          }
        }
      }
    }
  }
}
