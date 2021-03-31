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
        image             = "ghcr.io/femiwiki/mediawiki:latest"
        network_mode      = "host"
        memory_hard_limit = 600
      }

      env {
        FEMIWIKI_SERVER               = "http://127.0.0.1"
        NOMAD_UPSTREAM_ADDR_mysql     = "127.0.0.1:3306"
        NOMAD_UPSTREAM_ADDR_memcached = "127.0.0.1:11211"
        NOMAD_UPSTREAM_ADDR_parsoid   = "127.0.0.1:8000"
        NOMAD_UPSTREAM_ADDR_restbase  = "127.0.0.1:7231"
        NOMAD_UPSTREAM_ADDR_mathoid   = "127.0.0.1:10044"
        FEMIWIKI_DOMAIN               = "localhost"
        FEMIWIKI_DEBUG_MODE           = "1"
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
  }
}
