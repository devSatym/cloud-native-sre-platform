output "workload_identity_pool_id" {
  description = "Short ID of the GitHub workload identity pool."
  value       = google_iam_workload_identity_pool.github.workload_identity_pool_id
}

output "workload_identity_provider" {
  description = "Fully qualified provider resource name for google-github-actions/auth."
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "deployer_service_account_email" {
  description = "GitHub OIDC service account for image publishing and GKE deployment."
  value       = google_service_account.deployer.email
}

output "terraform_service_account_email" {
  description = "GitHub OIDC service account for guarded Terraform execution after bootstrap."
  value       = google_service_account.terraform.email
}
