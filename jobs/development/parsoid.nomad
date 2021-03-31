job "parsoid" {
  datacenters = ["dc1"]

  group "parsoid" {
    task "parsoid" {
      driver = "docker"

      config {
        image             = "ghcr.io/femiwiki/parsoid:latest"
        network_mode      = "host"
        memory_hard_limit = 400
      }

      resources {
        memory = 120
      }

      env {
        MEDIAWIKI_LINTING     = "true"
        MEDIAWIKI_APIS_DOMAIN = "localhost"
        MEDIAWIKI_APIS_URI    = "http://127.0.0.1/api.php"
      }
    }
  }
}
