datacenter = "dc1"
data_dir   = "/opt/nomad"

acl {
  enabled = true
}

server {
  enabled = true
  # A value of 1 does not provide any fault tolerance and is not recommended for production use cases.
  bootstrap_expect = 1
}

client {
  enabled = true

  host_volume "mysql" {
    path      = "/srv/mysql"
    read_only = false
  }

  host_volume "caddycerts" {
    path      = "/srv/caddycerts"
    read_only = false
  }
}

plugin "docker" {
  config {
    # CSI Node plugins must run as privileged Docker jobs
    allow_privileged = true

    # Cache
    volumes {
      enabled = true
    }
  }
}
