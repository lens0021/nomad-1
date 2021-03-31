job "bots" {
  datacenters = ["dc1"]

  group "backupbot" {
    task "backupbot" {
      driver = "docker"

      config {
        image = "ghcr.io/femiwiki/backupbot:2020-09-05T10-11-eefb914b"
        network_mode      = "host"
        memory_hard_limit = 600
      }

      # Todo provide envs DB_USERNAME and DB_PASSWORD
      # env {}

      resources {
        memory = 150
      }
    }
  }

  reschedule {
    attempts = 1
    interval  = "24h"
    unlimited = false
  }

  update {
    auto_revert = true
  }
}
