job "mediawiki" {
  datacenters = ["dc1"]

  # The update stanza specified at the job level will apply to all groups within the job
  update {
    max_parallel = 1
    health_check = "checks"
    auto_revert  = false
    auto_promote = true
    # canary count equal to the desired count allows a Nomad job to model blue/green deployments
    canary = 1
  }

  group "http" {
    task "http" {
      driver = "docker"

      config {
        image   = "ghcr.io/femiwiki/mediawiki:2021-03-21T09-12-c32a248f"
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

        memory_hard_limit = 400

        ulimit {
          nofile = "20000:40000"
        }
      }

      resources {
        memory = 80
      }

      env {
        CADDYPATH     = "/etc/caddycerts"
        FASTCGI_ADDR  = "${NOMAD_UPSTREAM_ADDR_fastcgi}"
        RESTBASE_ADDR = "${NOMAD_UPSTREAM_ADDR_restbase}"
      }
    }

    network {
      mode = "bridge"

      port "http" {
        static = 80
      }

      port "https" {
        static = 443
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

    restart {
      attempts = 0
    }

    reschedule {
      attempts       = 3
      interval       = "120s"
      delay          = "5s"
      delay_function = "constant"
      unlimited      = false
    }
  }

  group "fastcgi" {
    # Init Task Lifecycle
    # See https://www.nomadproject.io/docs/job-specification/lifecycle#init-task-pattern
    task "wait-for-db" {
      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      driver = "exec"
      config {
        command = "sh"
        # TODO Use Forward DNS for Consul Service Discovery
        # https://github.com/femiwiki/nomad/issues/8
        args = ["-c", "while [[ ! $(consul catalog services) == *mysql* ]]; do sleep 2; done"]
      }
    }

    task "fastcgi" {
      driver = "docker"

      config {
        image = "ghcr.io/femiwiki/mediawiki:2021-03-21T09-12-c32a248f"

        volumes = [
          "local/LocalSettings.php:/a/LocalSettings.php",
          "secrets/secret.php:/a/secret.php",
          "local/sitelist.xml:/a/sitelist.xml"
        ]

        mounts = [
          {
            type     = "volume"
            target   = "/tmp/cache"
            source   = "l18n_cache"
            readonly = false
          }
        ]

        memory_hard_limit = 600
      }

      resources {
        memory = 300
      }

      artifact {
        source      = "https://github.com/femiwiki/nomad/raw/main/configs/LocalSettings.php"
        destination = "local/LocalSettings.php"
        mode        = "file"
      }

      # TODO Replace Github source with S3
      # https://www.nomadproject.io/docs/job-specification/artifact#download-from-an-s3-compatible-bucket
      artifact {
        source      = "https://github.com/femiwiki/nomad/raw/main/configs/secret.php.example"
        destination = "secrets/secret.php"
        mode        = "file"
      }

      artifact {
        source      = "https://github.com/femiwiki/nomad/raw/main/configs/sitelist.xml"
        destination = "local/sitelist.xml"
        mode        = "file"
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

    volume "mysql" {
      type      = "csi"
      read_only = false
      source    = "mysql"
    }

    task "mysql" {
      driver = "docker"

      config {
        image   = "mysql:8.0.21"
        volumes = ["local/custom.cnf:/etc/mysql/conf.d/custom.cnf"]
        args    = [
          "--default-authentication-plugin=mysql_native_password",
          "--datadir", "/srv/mysql"
        ]
        memory_hard_limit = 1000
      }

      resources {
        memory = 500
      }

      volume_mount {
        # Container Storage Interface
        volume      = "mysql"
        destination = "/srv"
        read_only   = false
      }

      artifact {
        source      = "https://github.com/femiwiki/nomad/raw/main/mysql/custom.cnf"
        destination = "local/custom.cnf"
        mode        = "file"
      }

      env {
        MYSQL_RANDOM_ROOT_PASSWORD = "yes"
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
        image = "memcached:1.6.6-alpine"
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
    # Init Task Lifecycle
    # See https://www.nomadproject.io/docs/job-specification/lifecycle#init-task-pattern
    task "wait-for-mediawiki" {
      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      driver = "exec"
      config {
        command = "sh"
        args    = ["-c", "while ! nc -z localhost 80; do sleep 1; done"]
      }
    }

    task "parsoid" {
      driver = "docker"

      config {
        image = "ghcr.io/femiwiki/parsoid:2020-12-10T14-51-f84b9d2d"
        memory_hard_limit = 400
      }

      resources {
        memory = 120
      }

      env {
        MEDIAWIKI_LINTING     = "true"
        MEDIAWIKI_APIS_DOMAIN = "femiwiki.com"
        # Avoid using NOMAD_UPSTREAM_IP_http https://github.com/femiwiki/nomad/issues/1
        MEDIAWIKI_APIS_URI    = "http://localhost:${NOMAD_UPSTREAM_PORT_http}/api.php"
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
        image = "ghcr.io/femiwiki/restbase:2021-03-18T08-44-a48f917b"

        mounts = [
          {
            type     = "volume"
            target   = "/srv/restbase.sqlite3"
            source   = "restbase"
            readonly = false
          }
        ]

        memory_hard_limit = 400
      }

      resources {
        memory = 100
      }

      env {
        # Avoid using NOMAD_UPSTREAM_IP_http https://github.com/femiwiki/nomad/issues/1
        MEDIAWIKI_APIS_URI    = "http://localhost:${NOMAD_UPSTREAM_PORT_http}/api.php"
        MEDIAWIKI_APIS_DOMAIN = "femiwiki.com"
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
        image = "ghcr.io/femiwiki/mathoid:2020-12-09T04-56-c3db867c"
        memory_hard_limit = 600
      }

      resources {
        memory = 150
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
