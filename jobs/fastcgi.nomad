job "fastcgi" {
  datacenters = ["dc1"]

  # The update stanza specified at the job level will apply to all groups within the job
  update {
    auto_revert = true
  }

  group "fastcgi" {
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

      # TODO Replace Github source with S3
      # https://www.nomadproject.io/docs/job-specification/artifact#download-from-an-s3-compatible-bucket
      artifact {
        source      = "https://github.com/femiwiki/nomad/raw/main/configs/secret.php.example"
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
}
