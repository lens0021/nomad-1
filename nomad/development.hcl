server {
  default_scheduler_config {
    # Memory oversubscription is opt-in in Nomad 1.1
    memory_oversubscription_enabled = true
  }
}

client {
  cpu_total_compute = 5000 # 5000MHz
  # The memory that AWS t4g.small instance has
  memory_total_mb = 1900 # about 1.9GiB
}

plugin "docker" {
  config {
    volumes {
      enabled = true
    }
  }
}
