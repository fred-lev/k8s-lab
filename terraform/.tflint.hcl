config {
  module              = true
  force               = false
  disabled_by_default = false
  varfile             = ["terraform.tfvars"]
}

plugin "google" {
  enabled = true
  version = "0.9.0"
  source  = "github.com/terraform-linters/tflint-ruleset-google"
}
