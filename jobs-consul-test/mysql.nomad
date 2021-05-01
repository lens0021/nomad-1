job "mysql" {
  datacenters = ["dc1"]

  group "mysql" {
    # During test period
    # volume "mysql" {
    #   type      = "csi"
    #   source    = "mysql"
    #   read_only = false
    # }

    task "mysql" {
      driver = "docker"

      # During test period
      # volume_mount {
      #   volume      = "mysql"
      #   destination = "/srv/mysql"
      #   read_only   = false
      # }

      artifact {
        source      = "https://github.com/femiwiki/nomad/raw/main/mysql/custom.cnf"
        destination = "local/custom.cnf"
        mode        = "file"
      }

      config {
        image   = "mysql/mysql-server:8.0.23"
        volumes = ["local/custom.cnf:/etc/mysql/conf.d/custom.cnf"]
        args = [
          "--default-authentication-plugin=mysql_native_password",
          "--datadir", "/srv/mysql"
        ]
        memory_hard_limit = 800
      }

      resources {
        memory = 400
      }

      env {
        # During test period
        # MYSQL_RANDOM_ROOT_PASSWORD = "yes"
        MYSQL_ROOT_PASSWORD = "localfemiwikipassword"
        MYSQL_DATABASE      = "femiwiki"
        MYSQL_USER          = "DB_USERNAME" // secrets.php.example에 적힌 기본값
        MYSQL_PASSWORD      = "DB_PASSWORD" // secrets.php.example에 적힌 기본값
      }
    }

    network {
      mode = "bridge"
    }

    service {
      name = "mysql"
      port = "3306"

      connect {
        sidecar_service {}

        sidecar_task {
          config {
            memory_hard_limit = 500
          }
          resources {
            memory = 300
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
    auto_revert = true
  }
}
