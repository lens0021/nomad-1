# This is for test. See https://github.com/femiwiki/femiwiki/issues/253 for details.
datacenter = "dc1"
data_dir   = "/opt/nomad"

acl {
  enabled = true
}

server {
  enabled          = true
  bootstrap_expect = 2

  default_scheduler_config {
    # Memory oversubscription is opt-in in Nomad 1.1
    memory_oversubscription_enabled = true
  }
}

# We also use the server as a client.
client {
  enabled = true
}

plugin "docker" {
  config {
    # CSI Node plugins must run as privileged Docker jobs
    allow_privileged = true

    volumes {
      enabled = true
    }
  }
}
