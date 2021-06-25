server {
  default_scheduler_config {
    # Memory oversubscription is opt-in in Nomad 1.1
    memory_oversubscription_enabled = true
  }
}

client {
  reserved {
    cpu = 2500 # 2.5GHz
    # The memory that AWS t4g.small instance has
    memory = 2048
  }
}

plugin "docker" {
  config {
    volumes {
      enabled = true
    }
  }
}
