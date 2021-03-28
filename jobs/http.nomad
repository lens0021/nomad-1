job "http" {
  datacenters = ["dc1"]

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
            memory = 24
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
}
