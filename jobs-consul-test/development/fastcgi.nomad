variable "hotfix" {
  type    = string
  default = <<EOF
<?php
// Use this file for hotfixes

// Examples:
//
// $wgDebugToolbar = false;
// $wgDefaultSkin = 'vector';
EOF
}

job "fastcgi" {
  datacenters = ["dc1"]

  group "fastcgi" {
    task "fastcgi" {
      driver = "docker"

      artifact {
        source      = "https://raw.githubusercontent.com/femiwiki/docker-mediawiki/main/configs/secret.php.example"
        destination = "secrets/secrets.php"
        mode        = "file"
      }

      artifact {
        source      = "https://raw.githubusercontent.com/femiwiki/docker-mediawiki/main/development/site-list.xml"
        destination = "local/site-list.xml"
        mode        = "file"
      }

      template {
        data        = var.hotfix
        destination = "local/Hotfix.php"
        change_mode = "noop"
      }

      config {
        image             = "ghcr.io/femiwiki/mediawiki:latest"
        memory_hard_limit = 600

        volumes = [
          "secrets/secrets.php:/a/secret.php",
          "local/Hotfix.php:/a/Hotfix.php",
          "local/site-list.xml:/a/site-list.xml",
        ]

        mounts = [
          {
            type     = "volume"
            source   = "sitemap"
            target   = "/srv/femiwiki.com/sitemap"
            readonly = false
          }
        ]
      }

      env {
        MEDIAWIKI_DEBUG_MODE              = "1"
        MEDIAWIKI_SERVER                  = "http://127.0.0.1"
        MEDIAWIKI_DOMAIN_FOR_NODE_SERVICE = "localhost"
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
            memory_hard_limit = 500
          }
          resources {
            memory = 100
          }
        }
      }
    }
  }
}
