datacenter = "dc1"
data_dir   = "/opt/nomad"

server {
  enabled = true
  # A value of 1 does not provide any fault tolerance and is not recommended for production use cases.
  bootstrap_expect = 1
}

client {
  enabled = true
  # TODO Replate with S3
  # https://www.nomadproject.io/docs/job-specification/artifact#download-from-an-s3-compatible-bucket
  host_volume "secret" {
    # Please replace the path with available one
    # Reference: https://www.nomadproject.io/docs/configuration/client#host_volume-stanza
    path      = "/home/ec2-user/nomad/configs/secret.php"
    read_only = true
  }
}

plugin "docker" {
  config {
    # CSI Node plugins must run as privileged Docker jobs
    allow_privileged = true
  }
}
