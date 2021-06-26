job "mysql" {
  datacenters = ["dc1"]

  group "mysql" {
    task "mysql" {
      driver = "docker"

      artifact {
        source      = "https://github.com/femiwiki/nomad/raw/main/mysql/my.cnf"
        destination = "local/my.cnf"
        mode        = "file"

        options { checksum = "md5:9b1031516ada550d30a4e4184cc8ac58" }
      }

      config {
        image   = "mysql/mysql-server:8.0"
        volumes = ["local/my.cnf:/etc/mysql/my.cnf"]

        mounts = [
          {
            type     = "volume"
            source   = "mysql"
            target   = "/srv/mysql"
            readonly = false
          },
        ]
      }

      resources {
        memory     = 400
        memory_max = 800
      }

      env {
        MYSQL_ROOT_PASSWORD = "localfemiwikipassword"
        MYSQL_DATABASE      = "femiwiki"
        MYSQL_USER          = "DB_USERNAME" // secrets.php.example에 적힌 기본값
        MYSQL_PASSWORD      = "DB_PASSWORD" // secrets.php.example에 적힌 기본값
      }
    }

    network {
      mode = "bridge"

      port "mysql" {
        static = 3306
      }
    }
  }
}
