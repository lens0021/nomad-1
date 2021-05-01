variable "caddyfile_for_dev" {
  type    = string
  default = <<EOF
{
  # Global options
  auto_https off
  order mwcache before rewrite
}
127.0.0.1:{$NOMAD_HOST_PORT_http} localhost:{$NOMAD_HOST_PORT_http}
root * /srv/femiwiki.com
php_fastcgi {$NOMAD_UPSTREAM_ADDR_fastcgi}
file_server
encode gzip
mwcache {
	ristretto {
		num_counters 100000
		max_cost 10000
		buffer_items 64
	}
  purge_acl {
    10.0.0.0/8
    127.0.0.1
  }
}
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

log {
  output stdout
}
EOF
}

job "http" {
  datacenters = ["dc1"]

  group "http" {
    task "http" {
      driver = "docker"

      template {
        # Overwrite production Caddyfile
        data        = var.caddyfile_for_dev
        destination = "local/Caddyfile"
      }

      config {
        image   = "ghcr.io/femiwiki/mediawiki:latest"
        command = "caddy"
        args    = ["run"]

        # Mount volumes into the container
        # Reference: https://www.nomadproject.io/docs/drivers/docker#mounts
        mounts = [
          {
            type     = "volume"
            source   = "caddy"
            target   = "/etc/caddycerts"
            readonly = false
          },
          {
            type     = "volume"
            source   = "sitemap"
            target   = "/srv/femiwiki.com/sitemap"
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
            memory = 100
          }
        }
      }
    }
  }
}
