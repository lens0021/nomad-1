job "mathoid" {
  datacenters = ["dc1"]

  group "mathoid" {
    task "mathoid" {
      driver = "docker"

      config {
        image = "ghcr.io/femiwiki/mathoid:latest"
        memory_hard_limit = 600
      }

      resources {
        memory = 150
      }

      env {
        # Amazon EC2-t type small instances has two vCPUs
        MATHOID_NUM_WORKERS = "2"
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
            memory_hard_limit = 500
          }
          resources {
            memory = 100
          }
        }
      }
    }
  }
}
