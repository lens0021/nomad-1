variable "caddyfile_for_dev" {
  type    = string
  default = <<EOF
{
  # Global options
  auto_https off
}
127.0.0.1:{$NOMAD_HOST_PORT_http} localhost:{$NOMAD_HOST_PORT_http}
root * /srv/femiwiki.com
php_fastcgi {$NOMAD_UPSTREAM_ADDR_fastcgi}
file_server
encode gzip
header {
  # Enable XSS filtering for legacy browsers
  X-XSS-Protection "1; mode=block"
  # Block content sniffing, and enable Cross-Origin Read Blocking
  X-Content-Type-Options "nosniff"
  # Avoid clickjacking
  X-Frame-Options "DENY"
}
rewrite /w/api.php /api.php
rewrite /w/* /index.php

# Proxy requests to RESTBase
# Reference:
#   https://www.mediawiki.org/wiki/RESTBase/Installation#Proxy_requests_to_RESTBase_from_your_webserver
reverse_proxy /localhost/* {$NOMAD_UPSTREAM_ADDR_restbase}
EOF
}

job "http" {
  datacenters = ["dc1"]

  group "http" {
    task "http" {
      driver = "docker"

      config {
        image   = "ghcr.io/femiwiki/mediawiki:latest"
        command = "caddy"
        args    = ["run"]

        # Mount volumes into the container
        # Reference: https://www.nomadproject.io/docs/drivers/docker#mounts
        mounts = [
          {
            type     = "volume"
            target   = "/etc/caddycerts"
            source   = "caddy"
            readonly = false
          }
        ]

        volumes = [
          # Overwrite production Caddyfile
          "local/Caddyfile:/srv/femiwiki.com/Caddyfile"
        ]

        memory_hard_limit = 400
      }

      resources {
        memory = 80
      }

      template {
        # Overwrite the default caddyfile provided by femiwiki:mediawiki
        data = var.caddyfile_for_dev
        destination = "local/Caddyfile"
      }
    }

    network {
      mode = "bridge"

      port "http" {
        static = 80
      }

      port "https" {
        static = 443
      }
    }

    service {
      name = "http"
      port = "80"

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "fastcgi"
              local_bind_port  = 9000
            }

            upstreams {
              destination_name = "restbase"
              local_bind_port  = 7231
            }
          }
        }

        sidecar_task {
          config {
            memory_hard_limit = 500
          }
          resources {
            memory = 300
          }
        }
      }
    }
  }
}
