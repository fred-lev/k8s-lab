data "http" "main" {
  url = "https://ifconfig.me"
}

resource "google_compute_firewall" "internal" {
  name    = "k8s-lab-allow-internal"
  network = google_compute_network.main.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "ipip"
  }

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  source_ranges = [var.subnetwork_cidr_range]
}

resource "google_compute_firewall" "external" {
  name    = "k8s-lab-allow-external"
  network = google_compute_network.main.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22", "6443", "80", "8080", "30000-60000"]
  }

  source_ranges = ["${data.http.main.response_body}/32"]
}

resource "google_compute_network" "main" {
  name                    = "network-k8s-lab"
  auto_create_subnetworks = "false"
}

resource "google_compute_subnetwork" "main" {
  name          = "subnetwork-k8s-lab"
  ip_cidr_range = var.subnetwork_cidr_range
  region        = var.region
  network       = google_compute_network.main.id
}
