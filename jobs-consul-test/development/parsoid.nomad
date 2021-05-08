job "parsoid" {
  datacenters = ["dc1"]

  group "parsoid" {
    task "parsoid" {
      driver = "docker"

      config {
        image             = "ghcr.io/femiwiki/parsoid:latest"
        memory_hard_limit = 400
        ports             = ["parsoid"]
      }

      resources {
        memory = 120
      }

      env {
        # Amazon EC2-t type small instances has two vCPUs
        PARSOID_NUM_WORKERS   = "2"
        MEDIAWIKI_LINTING     = "true"
        MEDIAWIKI_APIS_DOMAIN = "localhost"
        MEDIAWIKI_APIS_URI    = "http://${NOMAD_UPSTREAM_ADDR_http}/api.php"
      }
    }

    network {
      mode = "bridge"

      port "parsoid" {
        to = 8000
      }
    }

    service {
      name         = "parsoid"
      port         = "8000"
      address_mode = "alloc"

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "http"
              local_bind_port  = 8080
            }
          }
        }
      }
    }
  }
}
