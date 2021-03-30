job "mysql" {
  datacenters = ["dc1"]

  group "mysql" {
    volume "mysql" {
      type      = "host"
      source    = "mysql"
      read_only = false
    }

    task "mysql" {
      driver = "docker"

      config {
        image   = "mysql:8.0.21"
        volumes = ["local/custom.cnf:/etc/mysql/conf.d/custom.cnf"]
        args    = [
          "--default-authentication-plugin=mysql_native_password",
          "--datadir", "/srv/mysql"
        ]
        memory_hard_limit = 1000
      }

      resources {
        memory = 400
      }

      volume_mount {
        volume      = "mysql"
        destination = "/srv"
        read_only   = false
      }

      artifact {
        source      = "https://github.com/femiwiki/nomad/raw/main/mysql/custom.cnf"
        destination = "local/custom.cnf"
        mode        = "file"
      }

      env {
        MYSQL_RANDOM_ROOT_PASSWORD = "yes"
      }
    }

    network {
      mode = "bridge"

      # Accessed by Backupbot
      port "mysql" {
        static = 3306
      }
    }

    service {
      name = "mysql"
      port = "3306"

      connect {
        sidecar_service {}

        sidecar_task {
          config {
            memory_hard_limit = 300
          }
          resources {
            memory = 20
          }
        }
      }
    }
  }

  reschedule {
    attempts  = 3
    interval  = "24h"
    delay     = "10s"
    unlimited = false
  }

  update {
    max_parallel = 1
    health_check = "checks"
    auto_revert  = true
    auto_promote = true
    # canary count equal to the desired count allows a Nomad job to model blue/green deployments
    canary = 1
  }
}
