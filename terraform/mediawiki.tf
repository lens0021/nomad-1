data "nomad_plugin" "ebs" {
  plugin_id        = "aws-ebs0"
  wait_for_healthy = true
}

resource "nomad_job" "mysql" {
  detach     = false
  jobspec    = file("../jobs/mysql.nomad")

  hcl2 {
    enabled  = true
    allow_fs = true
  }
}

resource "nomad_job" "memcached" {
  detach  = false
  jobspec = file("../jobs/memcached.nomad")

  hcl2 {
    enabled  = true
    allow_fs = true
  }
}

resource "nomad_job" "fastcgi" {
  depends_on = [
    nomad_job.mysql,
    nomad_job.memcached,
  ]
  detach  = false
  jobspec = file("../jobs/fastcgi.nomad")

  hcl2 {
    enabled  = true
    allow_fs = true
  }
}

resource "nomad_job" "http" {
  detach  = false
  jobspec = file("../jobs/http.nomad")

  hcl2 {
    enabled  = true
    allow_fs = true
  }
}

resource "nomad_job" "parsoid" {
  depends_on = [
    nomad_job.fastcgi,
    nomad_job.http,
  ]
  detach  = false
  jobspec = file("../jobs/parsoid.nomad")

  hcl2 {
    enabled  = true
    allow_fs = true
  }
}

resource "nomad_job" "restbase" {
  detach  = false
  jobspec = file("../jobs/restbase.nomad")

  hcl2 {
    enabled  = true
    allow_fs = true
  }
}

resource "nomad_job" "mathoid" {
  detach  = false
  jobspec = file("../jobs/mathoid.nomad")

  hcl2 {
    enabled  = true
    allow_fs = true
  }
}
