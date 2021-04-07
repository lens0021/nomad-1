job "fastcgi" {
  datacenters = ["dc1"]

  group "fastcgi" {
    # Init Task Lifecycle
    # See https://www.nomadproject.io/docs/job-specification/lifecycle#init-task-pattern
    task "wait-for-backend" {
      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      driver = "exec"
      config {
        command = "sh"
        args    = [
          "-c",
          join( ";", [
            "while ! ncat --send-only 127.0.0.1 3306 < /dev/null; do sleep 1; done",
            "while ! ncat --send-only 127.0.0.1 11211 < /dev/null; do sleep 1; done"
          ] )
        ]
      }
    }

    volume "secrets" {
      type      = "host"
      source    = "secrets"
      read_only = true
    }

    volume "file_cache" {
      type      = "host"
      source    = "file_cache"
      read_only = false
    }

    task "fastcgi" {
      driver = "docker"

      config {
        image = "ghcr.io/femiwiki/mediawiki:2021-03-30T15-34-a70e0d27"

        mounts = [
          {
            type     = "volume"
            target   = "/tmp/cache"
            source   = "l18n_cache"
            readonly = false
          }
        ]

        network_mode      = "host"
        memory_hard_limit = 600
      }

      volume_mount {
        volume      = "secrets"
        destination = "/a"
        read_only   = true
      }

      volume_mount {
        volume      = "file_cache"
        destination = "/tmp/file-cache"
        read_only   = false
      }


      env {
        FEMIWIKI_SERVER               = "https://femiwiki.com"
        NOMAD_UPSTREAM_ADDR_memcached = "127.0.0.1:11211"
        NOMAD_UPSTREAM_ADDR_parsoid   = "127.0.0.1:8000"
        NOMAD_UPSTREAM_ADDR_restbase  = "127.0.0.1:7231"
        NOMAD_UPSTREAM_ADDR_mathoid   = "127.0.0.1:10044"
      }

      resources {
        memory = 110
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
