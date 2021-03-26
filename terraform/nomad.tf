variable "persistent_ebs_id" {
  type = string
}

resource "nomad_job" "plugin-ebs-controller" {
  jobspec = file("../nomad/plugin-ebs-controller.nomad")

  hcl2 {
    enabled  = true
    allow_fs = true
  }
}

resource "nomad_job" "plugin-ebs-nodes" {
  jobspec = file("../nomad/plugin-ebs-nodes.nomad")

  hcl2 {
    enabled  = true
    allow_fs = true
  }
}

data "nomad_plugin" "ebs" {
  plugin_id        = "aws-ebs0"
  wait_for_healthy = true
}

resource "nomad_volume" "mysql" {
  depends_on      = [data.nomad_plugin.ebs]
  type            = "csi"
  plugin_id       = "aws-ebs0"
  volume_id       = "mysql"
  name            = "mysql"
  external_id     = var.persistent_ebs_id
  access_mode     = "single-node-writer"
  attachment_mode = "file-system"
}

resource "nomad_job" "mediawiki" {
  depends_on = [nomad_volume.mysql]
  detach     = false
  jobspec    = file("../nomad/production.nomad")

  hcl2 {
    enabled  = true
    allow_fs = true
  }
}
