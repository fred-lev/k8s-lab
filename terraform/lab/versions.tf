terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 3.73"
    }
    http = {
      source  = "hashicorp/http"
      version = ">= 2.1"
    }
  }
}
