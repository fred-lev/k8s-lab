terraform {
  backend "gcs" {
    bucket = "tf-state-k8s-lab-flev"
    prefix = "k8s-lab"
  }
}
