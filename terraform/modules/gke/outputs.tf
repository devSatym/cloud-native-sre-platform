output "cluster_name" {
  description = "Name of the zonal Standard GKE cluster."
  value       = google_container_cluster.this.name
}

output "cluster_location" {
  description = "Zone containing the GKE cluster."
  value       = google_container_cluster.this.location
}

output "cluster_endpoint" {
  description = "GKE control-plane endpoint."
  value       = google_container_cluster.this.endpoint
}

output "node_service_account_email" {
  description = "Dedicated service account email used by GKE nodes."
  value       = google_service_account.nodes.email
}

output "workload_identity_pool" {
  description = "Kubernetes Workload Identity pool used by this GKE cluster."
  value       = "${var.project_id}.svc.id.goog"
}
