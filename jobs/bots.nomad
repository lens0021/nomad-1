job "bots" {
  datacenters = ["dc1"]

  # The update stanza specified at the job level will apply to all groups within the job
  update {
    max_parallel = 1
    health_check = "checks"
    auto_revert  = false
    auto_promote = true
    # canary count equal to the desired count allows a Nomad job to model blue/green deployments
    canary = 1
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
