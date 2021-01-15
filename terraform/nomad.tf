// Must set TF_VAR_PERSISTENT_EBS_ID
variable "PERSISTENT_EBS_ID" {}

resource "nomad_job" "plugin-ebs-controller" {
  jobspec = file("../nomad/plugin-ebs-controller.nomad")
}

resource "nomad_job" "plugin-ebs-nodes" {
  jobspec = file("../nomad/plugin-ebs-nodes.nomad")
}

data "nomad_plugin" "ebs" {
  plugin_id        = "aws-ebs0"
  wait_for_healthy = true
}

resource "nomad_volume" "mysql_volume" {
  depends_on      = [data.nomad_plugin.ebs]
  type            = "csi"
  plugin_id       = "aws-ebs0"
  volume_id       = "mysql"
  name            = "mysql"
  external_id     = var.PERSISTENT_EBS_ID
  access_mode     = "single-node-writer"
  attachment_mode = "file-system"
}

resource "nomad_job" "mediawiki" {
  depends_on = [nomad_volume.mysql_volume]
  jobspec    = file("../nomad/production.nomad")
}
