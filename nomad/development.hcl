server {
  default_scheduler_config {
    # Memory oversubscription is opt-in in Nomad 1.1
    memory_oversubscription_enabled = true
  }
}

plugin "docker" {
  config {
    volumes {
      enabled = true
    }
  }
}
