job "mysql" {
  datacenters = ["dc1"]

  group "mysql" {

    volume "mysql" {
      type      = "csi"
      read_only = false
      source    = "mysql"
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
        memory = 500
      }

      volume_mount {
        # Container Storage Interface
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
            memory = 24
          }
        }
      }
    }
  }
}
