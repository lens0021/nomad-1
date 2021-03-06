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
        # Amazon EC2 t3a-small has two vCPUs
        MATHOID_NUM_WORKERS = "2"
      }
    }

    network {
      mode = "bridge"

      port "mathoid" {
        static = 10044
      }
    }
  }
}
