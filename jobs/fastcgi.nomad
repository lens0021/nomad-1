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

    task "fastcgi" {
      driver = "docker"

      config {
        image = "ghcr.io/femiwiki/mediawiki:2021-03-21T09-12-c32a248f"

        volumes = [
          "local/LocalSettings.php:/a/LocalSettings.php",
          "secrets/secret.php:/a/secret.php",
          "local/sitelist.xml:/a/sitelist.xml"
        ]

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

      resources {
        memory = 100
      }

      artifact {
        source      = "https://github.com/femiwiki/nomad/raw/main/configs/LocalSettings.php"
        destination = "local/LocalSettings.php"
        mode        = "file"
      }

      artifact {
        source      = "s3::https://femiwiki-secrets.s3-ap-northeast-1.amazonaws.com/secrets.php"
        destination = "secrets/secret.php"
        mode        = "file"
      }

      artifact {
        source      = "https://github.com/femiwiki/nomad/raw/main/configs/sitelist.xml"
        destination = "local/sitelist.xml"
        mode        = "file"
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
