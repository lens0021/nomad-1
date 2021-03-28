job "memcached" {
  datacenters = ["dc1"]

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
}
