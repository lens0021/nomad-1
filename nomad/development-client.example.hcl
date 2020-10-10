client {
  host_volume "configs" {
    # Please replace the path with available one
    # Reference: https://www.nomadproject.io/docs/configuration/client#host_volume-stanza
    path      = "/path/to/configs"
    read_only = true
  }
}

plugin "docker" {
  config {
    volumes {
      enabled = true
    }
  }
}
