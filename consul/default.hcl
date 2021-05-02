datacenter = "dc1"
data_dir   = "/opt/consul"

server           = true
bind_addr        = "{{GetInterfaceIP \"eth0\"}}"
bootstrap_expect = 2
# Cloud Auto-join
# https://www.consul.io/docs/install/cloud-auto-join#amazon-ec2
retry_join = ["provider=aws tag_key=Nomad tag_value=femiwiki"]

ports {
  grpc = 8502
}

connect {
  enabled = true
}
