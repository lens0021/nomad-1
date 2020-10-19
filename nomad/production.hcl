datacenter = "dc1"
data_dir = "/opt/nomad"

server {
  enabled = true
  # A value of 1 does not provide any fault tolerance and is not recommended for production use cases.
  bootstrap_expect = 1
}

client {
  enabled = true
}
