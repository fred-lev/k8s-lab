controller = {
  image_family  = "ubuntu-1804-lts"
  image_project = "ubuntu-os-cloud"
  machine_type  = "n1-standard-2"
}

project               = "tidy-strand-340704"
region                = "asia-southeast1"
subnetwork_cidr_range = "10.240.0.0/24"

worker = {
  count         = 3
  image_family  = "ubuntu-1804-lts"
  image_project = "ubuntu-os-cloud"
  machine_type  = "n1-standard-2"
}

zone = "asia-southeast1-c"
