job "restbase" {
  datacenters = ["dc1"]

  update {
    max_parallel = 1
    health_check = "checks"
    auto_revert  = false
    auto_promote = true
    # canary count equal to the desired count allows a Nomad job to model blue/green deployments
    canary = 1
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
        MEDIAWIKI_APIS_DOMAIN = "femiwiki.com"
        MEDIAWIKI_APIS_URI    = "http://${NOMAD_UPSTREAM_ADDR_http}/api.php"
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
              local_bind_port  = 8080
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
            memory = 24
          }
        }
      }
    }
  }
}
