job "fastcgi" {
  datacenters = ["dc1"]

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
        memory = 100
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
}
