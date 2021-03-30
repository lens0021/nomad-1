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
            "while ! ncat --send-only ${NOMAD_UPSTREAM_IP_mysql} ${NOMAD_UPSTREAM_PORT_mysql} < /dev/null; do sleep 1; done",
            "while ! ncat --send-only ${NOMAD_UPSTREAM_IP_memcached} ${NOMAD_UPSTREAM_PORT_memcached} < /dev/null; do sleep 1; done"
          ] )
        ]
      }
    }

    volume "secrets" {
      type      = "host"
      source    = "secrets"
      read_only = true
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

        memory_hard_limit = 600
      }

      volume_mount {
        volume      = "secrets"
        destination = "/a"
        read_only   = true
      }

      env {
        # Change server during porting
        FEMIWIKI_SERVER = "https://test.femiwiki.com"
      }

      resources {
        memory = 100
      }
    }

    network {
      mode = "bridge"
    }

    service {
      name = "fastcgi"
      port = "9000"

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "mysql"
              local_bind_port  = 3306
            }

            upstreams {
              destination_name = "memcached"
              local_bind_port  = 11211
            }

            upstreams {
              destination_name = "parsoid"
              local_bind_port  = 8000
            }

            upstreams {
              destination_name = "restbase"
              local_bind_port  = 7231
            }

            upstreams {
              destination_name = "mathoid"
              local_bind_port  = 10044
            }
          }
        }

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
