variable "controller" {
  type        = map(string)
  description = "Kubernetes controller nodes."
}

variable "project" {
  type        = string
  description = "Name of the google cloud project."
}

variable "region" {
  type        = string
  description = "Region where resources should be deployed."
}

variable "subnetwork_cidr_range" {
  type        = string
  description = "Ip range to use for the subnetwork"
}

variable "worker" {
  type        = map(string)
  description = "Kubernetes worker nodes."
}

variable "zone" {
  type        = string
  description = "Zone where resources should be deployed."
}
