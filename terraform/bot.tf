resource "nomad_job" "backupbot" {
  detach  = false
  jobspec = file("../jobs/backupbot.nomad")

  hcl2 {
    enabled  = true
    allow_fs = true
  }
}
