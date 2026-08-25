output "project_id" {
  description = "Set this value as the GitHub Actions GCP_PROJECT_ID variable."
  value       = var.project_id
}

output "region" {
  description = "Set this value as the GitHub Actions GCP_REGION variable."
  value       = var.region
}

output "zone" {
  description = "Set this value as the GitHub Actions GCP_ZONE variable."
  value       = var.zone
}

output "artifact_registry_repository" {
  description = "Set this value as the GitHub Actions ARTIFACT_REGISTRY_REPOSITORY variable."
  value       = module.artifact_registry.repository_id
}

output "artifact_registry_repository_url" {
  description = "Docker repository URL; append /api:<git-sha> or /payments:<git-sha>."
  value       = module.artifact_registry.repository_url
}

output "api_image_repository" {
  description = "API image base URL; CI appends an immutable Git SHA tag."
  value       = module.artifact_registry.api_image_repository
}

output "payments_image_repository" {
  description = "Payments image base URL; CI appends an immutable Git SHA tag."
  value       = module.artifact_registry.payments_image_repository
}

output "workload_identity_provider" {
  description = "Set this full resource name as the GitHub Actions GCP_WORKLOAD_IDENTITY_PROVIDER variable."
  value       = module.github_wif.workload_identity_provider
}

output "deployer_service_account_email" {
  description = "Set this value as the GitHub Actions GCP_DEPLOYER_SERVICE_ACCOUNT variable."
  value       = module.github_wif.deployer_service_account_email
}

output "terraform_service_account_email" {
  description = "Set this value as the GitHub Actions GCP_TERRAFORM_SERVICE_ACCOUNT variable after bootstrap."
  value       = module.github_wif.terraform_service_account_email
}

output "cluster_name" {
  description = "Set this value as the GitHub Actions GKE_CLUSTER_NAME variable."
  value       = module.gke.cluster_name
}

output "cluster_location" {
  description = "Set this zonal value as the GitHub Actions GKE_CLUSTER_LOCATION variable."
  value       = module.gke.cluster_location
}

output "cluster_endpoint" {
  description = "GKE control-plane endpoint."
  value       = module.gke.cluster_endpoint
}

output "gke_node_service_account_email" {
  description = "Dedicated GKE node service account with repository-scoped Artifact Registry pull access."
  value       = module.gke.node_service_account_email
}
