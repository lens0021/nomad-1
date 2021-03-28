job "mathoid" {
  datacenters = ["dc1"]

  update {
    max_parallel = 1
    health_check = "checks"
    auto_revert  = false
    auto_promote = true
    # canary count equal to the desired count allows a Nomad job to model blue/green deployments
    canary = 1
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
            memory = 24
          }
        }
      }
    }
  }
}
