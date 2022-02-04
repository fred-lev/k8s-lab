/*
A key set in project metadata is propagated to every instance in the project.
This resource configuration is prone to causing frequent diffs as Google adds SSH Keys when the SSH Button is pressed in the console.
It is better to use OS Login instead.
*/
resource "google_compute_project_metadata" "my_ssh_key" {
  metadata = {
    ssh-keys = <<EOF
      flevlab:ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPuWU7PYZmxempCu8pw8YJ654xN+1H1HIOh24pqAvJTw lab@flev.fr
    EOF
  }
}

resource "google_compute_address" "controller" {
  name = "pub-ip-controller-01"
}

resource "google_compute_address" "worker" {
  count = var.worker.count

  name = format("pub-ip-worker-%02d", count.index + 1)
}

resource "google_compute_instance" "controller" {
  #ts:skip=accurics.gcp.NS.130 can_ip_forward needed worker kubernetes.
  can_ip_forward = true
  labels = {
    kind = "controller"
  }
  machine_type = var.controller.machine_type
  name         = "k8s-lab-controller-01"
  tags         = ["controller", "k8s-lab"]
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = format("%s/%s", var.controller.image_project, var.controller.image_family)
      size  = 30
      type  = "pd-ssd"
    }
  }

  network_interface {
    network    = google_compute_network.main.name
    network_ip = format("10.240.0.11")
    subnetwork = google_compute_subnetwork.main.name
    access_config {
      nat_ip = google_compute_address.controller.address
    }
  }
}

resource "google_compute_instance" "worker" {
  #ts:skip=accurics.gcp.NS.130 can_ip_forward needed worker kubernetes.
  count = var.worker.count

  can_ip_forward = true
  labels = {
    kind = "workers"
  }
  machine_type = var.worker.machine_type
  name         = format("k8s-lab-worker-%02d", count.index + 1)
  tags         = ["worker", "k8s-lab"]
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = format("%s/%s", var.worker.image_project, var.worker.image_family)
      size  = 30
      type  = "pd-ssd"
    }
  }

  network_interface {
    network    = google_compute_network.main.name
    network_ip = format("10.240.0.2%d", count.index + 1)
    subnetwork = google_compute_subnetwork.main.name
    access_config {
      nat_ip = google_compute_address.worker[count.index].address
    }
  }
}
