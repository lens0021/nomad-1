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
        image   = "ghcr.io/femiwiki/mediawiki:2020-10-18T06-03-9e5503e1"
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
      }

      env {
        FASTCGI_ADDR  = "${NOMAD_UPSTREAM_ADDR_fastcgi}"
        RESTBASE_ADDR = "${NOMAD_UPSTREAM_ADDR_restbase}"
      }

      resources {
        memory = 24
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
    volume "secret" {
      type   = "host"
      source = "secret"
      read_only = true
    }

    task "fastcgi" {
      driver = "docker"

      config {
        image = "ghcr.io/femiwiki/mediawiki:2020-10-18T06-03-9e5503e1"

        volumes = [
          "local/LocalSettings.php:/a/LocalSettings.php",
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
      }

      artifact {
        source      = "https://github.com/femiwiki/nomad/raw/master/configs/LocalSettings.php"
        destination = "local/LocalSettings.php"
        mode        = "file"
      }

      artifact {
        source      = "https://github.com/femiwiki/nomad/raw/master/configs/sitelist.xml"
        destination = "local/sitelist.xml"
        mode        = "file"
      }

      volume_mount {
        volume      = "secret"
        destination = "/a/secret.php"
        read_only = true
      }

      resources {
        memory = 110
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
      }

      volume_mount {
        volume      = "mysql"
        destination = "/srv"
        read_only   = false
      }

      artifact {
        source      = "https://github.com/femiwiki/nomad/raw/master/mysql/custom.cnf"
        destination = "local/custom.cnf"
        mode        = "file"
      }

      env {
        MYSQL_RANDOM_ROOT_PASSWORD = "yes"
      }

      resources {
        memory = 512
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
      }
    }
  }

  group "memcached" {
    task "memcached" {
      driver = "docker"

      config {
        image = "memcached:1.6.6-alpine"
      }

      resources {
        memory = 80
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
      }
    }
  }

  group "parsoid" {
    task "parsoid" {
      driver = "docker"

      config {
        image = "ghcr.io/femiwiki/parsoid:2020-09-05T10-03-ae442600"
      }

      env {
        MEDIAWIKI_LINTING     = "true"
        MEDIAWIKI_APIS_DOMAIN = "localhost"
        # Avoid using NOMAD_UPSTREAM_ADDR_http https://github.com/femiwiki/nomad/issues/1
        MEDIAWIKI_APIS_URI    = "http://localhost/api.php"
      }

      resources {
        memory = 150
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
      }
    }
  }

  group "restbase" {
    task "restbase" {
      driver = "docker"

      config {
        image = "ghcr.io/femiwiki/restbase:2020-09-05T10-04-5dcdc8b6"

        mounts = [
          {
            type     = "volume"
            target   = "/srv/restbase.sqlite3"
            source   = "restbase"
            readonly = false
          }
        ]
      }

      env {
        # Avoid using NOMAD_UPSTREAM_ADDR_http https://github.com/femiwiki/nomad/issues/1
        MEDIAWIKI_APIS_URI    = "http://localhost/api.php"
        MEDIAWIKI_APIS_DOMAIN = "localhost"
        PARSOID_URI           = "http://${NOMAD_UPSTREAM_ADDR_parsoid}"
        MATHOID_URI           = "http://${NOMAD_UPSTREAM_ADDR_mathoid}"
      }

      resources {
        memory = 128
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
      }
    }
  }

  group "mathoid" {
    task "mathoid" {
      driver = "docker"

      config {
        image = "wikimedia/mathoid:bad5ec8d4"
      }

      resources {
        memory = 128
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
      }
    }
  }
}
