resource "google_compute_network" "this" {
  project                         = var.project_id
  name                            = var.network_name
  auto_create_subnetworks         = false
  delete_default_routes_on_create = false
  routing_mode                    = "REGIONAL"
  description                     = "Custom VPC for the Cloud Native SRE Platform."
}

resource "google_compute_subnetwork" "gke" {
  project                  = var.project_id
  name                     = var.subnetwork_name
  region                   = var.region
  network                  = google_compute_network.this.id
  ip_cidr_range            = var.subnetwork_cidr
  private_ip_google_access = true
  description              = "Regional subnet for GKE nodes and alias IP ranges."

  secondary_ip_range {
    range_name    = var.pods_secondary_range_name
    ip_cidr_range = var.pods_secondary_cidr
  }

  secondary_ip_range {
    range_name    = var.services_secondary_range_name
    ip_cidr_range = var.services_secondary_cidr
  }
}

# GKE creates its own control-plane-to-node rule. This rule is intentionally
# limited to the source ranges and NodePort range required for external load
# balancer health checks.
resource "google_compute_firewall" "allow_gke_health_checks" {
  project       = var.project_id
  name          = "${var.network_name}-allow-gke-health-checks"
  network       = google_compute_network.this.id
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = var.health_check_source_ranges
  target_tags   = var.node_network_tags
  description   = "Permit Google Cloud Load Balancer health checks to GKE NodePorts."

  allow {
    protocol = "tcp"
    ports    = ["30000-32767"]
  }
}
