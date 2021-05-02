# During test period
variable "caddyfile_for_dev" {
  type    = string
  default = <<EOF
{
  # Global options
  auto_https off
  order mwcache before rewrite
}
:{$NOMAD_HOST_PORT_http}
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
reverse_proxy /localhost/* 127.0.0.1:7231

log {
  output stdout
}

EOF
}

job "http" {
  datacenters = ["dc1"]

  group "http" {
    # During test period
    # volume "caddycerts" {
    #   type      = "csi"
    #   source    = "caddycerts"
    #   read_only = false
    # }

    task "http" {
      driver = "docker"

      # During test period
      # volume_mount {
      #   volume      = "caddycerts"
      #   destination = "/etc/caddycerts"
      #   read_only   = false
      # }

      # During test period
      template {
        # Overwrite the default caddyfile provided by femiwiki:mediawiki
        data        = var.caddyfile_for_dev
        destination = "local/Caddyfile"
      }

      # During test period
      # artifact {
      #   source      = "https://github.com/femiwiki/nomad/raw/main/caddy/Caddyfile"
      #   destination = "local/Caddyfile"
      #   mode        = "file"
      # }

      config {
        image   = "ghcr.io/femiwiki/mediawiki:2021-04-19T12-14-11fd8960"
        command = "caddy"
        args    = ["run"]
        volumes = ["local/Caddyfile:/srv/femiwiki.com/Caddyfile"]

        # Mount volume into the container
        # Reference: https://www.nomadproject.io/docs/drivers/docker#mounts
        mounts = [
          {
            type     = "volume"
            target   = "/srv/femiwiki.com/sitemap"
            source   = "sitemap"
            readonly = false
          },
        ]

        # Increase max fd number
        # https://github.com/femiwiki/docker-mediawiki/issues/467
        ulimit {
          nofile = "20000:40000"
        }
        memory_hard_limit = 400
      }

      resources {
        memory = 100
      }

      env {
        CADDYPATH     = "/etc/caddycerts"
        FASTCGI_ADDR  = "127.0.0.1:9000"
        RESTBASE_ADDR = "127.0.0.1:7231"
      }
    }

    # TODO avoid static port
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

    restart {
      attempts = 0
    }
  }

  reschedule {
    attempts       = 3
    interval       = "120s"
    delay          = "5s"
    delay_function = "constant"
    unlimited      = false
  }

  update {
    auto_revert = true
  }
}
