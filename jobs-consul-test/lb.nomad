# https://learn.hashicorp.com/tutorials/nomad/load-balancing-traefik
job "lb" {
  datacenters = ["dc1"]

  constraint {
    attribute = "${unique.platform.aws.local-ipv4}"
    # TODO Replace this with a network interface
    value = "172.31.26.55"
  }

  group "lb" {
    count = 1

    network {
      port "http" {
        static = 80
      }

      port "https" {
        static = 443
      }
    }

    service {
      name = "lb"

      check {
        name     = "alive"
        type     = "tcp"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "lb" {
      driver = "docker"

      artifact {
        source      = "https://github.com/femiwiki/nomad/raw/main/traefik/traefik.toml"
        destination = "local/traefik.toml"
        mode        = "file"
      }

      config {
        image        = "traefik:v2.4.8"
        network_mode = "host"
        ports        = ["http", "https"]
        volumes      = ["local/traefik.toml:/etc/traefik/traefik.toml"]

        mounts = [
          {
            type     = "volume"
            source   = "certificates"
            target   = "/etc/certificates"
            readonly = false
          },
        ]

        memory_hard_limit = 500
      }

      resources {
        memory = 128
      }
    }
  }
}