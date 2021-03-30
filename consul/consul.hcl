datacenter = "dc1"
data_dir   = "/opt/consul"

server           = true
node_name        = "femiwiki"
bootstrap_expect = 1
# Workaround for single node environment.
# https://github.com/hashicorp/consul/issues/7137
retry_join       = ["127.0.0.1"]

ports {
  grpc = 8502
}

connect {
  enabled = true
}
