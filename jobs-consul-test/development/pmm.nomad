# TODO
job "pmm" {
  datacenters = ["dc1"]

  group "server" {
    task "server" {
      driver = "docker"

      config {
        image             = "percona/pmm-server:2"
        memory_hard_limit = 1000
        network_mode      = "host"

        mount = [
          {
            type     = "volume"
            source   = "pmm-data"
            target   = "/srv"
            readonly = false
          },
        ]
      }

      resources {
        memory = 300
      }
    }

    service {
      name         = "pmm-server"
      port         = "443"
      address_mode = "alloc"

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "mysql"
              local_bind_port  = 3306
            }
          }
        }
      }
    }
  }

  group "client" {

    task "client" {
      driver = "docker"

      config {
        image             = "percona/pmm-client:2"
        memory_hard_limit = 1000
        network_mode      = "host"
        # entrypoint        = ["pmm-agent", "setup"]

        mount = [
          {
            type     = "volume"
            source   = "pmm-client-data"
            target   = "/srv"
            readonly = false
          },
        ]
      }

      env {
        PMM_AGENT_CONFIG_FILE         = "/etc/pmm-agent.yaml"
        PMM_AGENT_SERVER_USERNAME     = "admin"
        PMM_AGENT_SERVER_PASSWORD     = "admin_password_please_change"
        PMM_AGENT_SERVER_ADDRESS      = "${NOMAD_UPSTREAM_ADDR_pmm-server}"
        PMM_AGENT_SERVER_INSECURE_TLS = "true"
      }

      resources {
        memory = 300
      }
    }

    service {
      name         = "pmm-client"
      port         = "42000"
      address_mode = "alloc"

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "pmm-server"
              local_bind_port  = 443
            }
          }
        }
      }
    }

    service {
      name         = "pmm-client"
      port         = "42001"
      address_mode = "alloc"

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "pmm-server"
              local_bind_port  = 443
            }
          }
        }
      }
    }
  }
}
