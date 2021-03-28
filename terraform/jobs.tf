data "nomad_plugin" "ebs" {
  plugin_id        = "aws-ebs0"
  wait_for_healthy = true
}

resource "nomad_job" "mediawiki" {
  depends_on = [nomad_volume.mysql]
  detach     = false
  jobspec    = file("../jobs/production.nomad")

  hcl2 {
    enabled  = true
    allow_fs = true
  }
}
