job "parsoid" {
  datacenters = ["dc1"]

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
        MEDIAWIKI_APIS_URI    = "http://${NOMAD_UPSTREAM_ADDR_http}/api.php"
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
              local_bind_port  = 8080
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
}