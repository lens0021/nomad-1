job "memcached" {
  datacenters = ["dc1"]

  update {
    max_parallel = 1
    health_check = "checks"
    auto_revert  = false
    auto_promote = true
    # canary count equal to the desired count allows a Nomad job to model blue/green deployments
    canary = 1
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
            memory = 24
          }
        }
      }
    }
  }
}
