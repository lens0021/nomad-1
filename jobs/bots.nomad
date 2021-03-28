job "bots" {
  datacenters = ["dc1"]

  update {
    auto_revert = true
  }

  group "backupbot" {
    task "backupbot" {
      driver = "docker"

      config {
        image = "ghcr.io/femiwiki/backupbot:2020-09-05T10-11-eefb914b"
        memory_hard_limit = 600
      }

      # Todo provide envs DB_USERNAME and DB_PASSWORD
      # env {}

      resources {
        memory = 150
      }
    }

    network {
      # todo change to host
      mode = "bridge"
    }
  }
}
