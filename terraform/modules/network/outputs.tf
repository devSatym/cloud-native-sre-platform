output "network_id" {
  description = "Self-link of the custom VPC network."
  value       = google_compute_network.this.id
}

output "network_name" {
  description = "Name of the custom VPC network."
  value       = google_compute_network.this.name
}

output "subnetwork_id" {
  description = "Self-link of the GKE subnet."
  value       = google_compute_subnetwork.gke.id
}

output "subnetwork_name" {
  description = "Name of the GKE subnet."
  value       = google_compute_subnetwork.gke.name
}

output "pods_secondary_range_name" {
  description = "Subnet secondary range name used for GKE Pods."
  value       = var.pods_secondary_range_name
}

output "services_secondary_range_name" {
  description = "Subnet secondary range name used for GKE Services."
  value       = var.services_secondary_range_name
}
