terraform {
  backend "gcs" {
    bucket = "tf-state-k8s-lab"
    prefix = "k8s-lab"
  }
}
