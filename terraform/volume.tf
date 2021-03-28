variable "persistent_ebs_id" {
  type = string
}

resource "nomad_job" "plugin-ebs-controller" {
  jobspec = file("../jobs/plugin-ebs-controller.nomad")

  hcl2 {
    enabled  = true
    allow_fs = true
  }
}

resource "nomad_job" "plugin-ebs-nodes" {
  jobspec = file("../jobs/plugin-ebs-nodes.nomad")

  hcl2 {
    enabled  = true
    allow_fs = true
  }
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
