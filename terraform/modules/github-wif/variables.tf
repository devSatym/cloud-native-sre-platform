variable "project_id" {
  description = "Google Cloud project ID that owns the workload identity resources."
  type        = string
}

variable "github_repository" {
  description = "Exact GitHub repository allowed to exchange OIDC tokens, in owner/repository form."
  type        = string

  validation {
    condition     = can(regex("^[^/]+/[^/]+$", var.github_repository))
    error_message = "github_repository must use the owner/repository form."
  }
}

variable "workload_identity_pool_id" {
  description = "Short ID for the GitHub workload identity pool."
  type        = string
}

variable "workload_identity_pool_provider_id" {
  description = "Short ID for the GitHub OIDC provider."
  type        = string
}

variable "deployer_service_account_id" {
  description = "Account ID for the GitHub image-publish and GKE deployment identity."
  type        = string
}

variable "terraform_service_account_id" {
  description = "Account ID for the GitHub Terraform executor identity."
  type        = string
}

variable "artifact_registry_location" {
  description = "Location of the Artifact Registry Docker repository."
  type        = string
}

variable "artifact_registry_repository_id" {
  description = "Short ID of the Docker repository to which the deployer can push images."
  type        = string
}

variable "terraform_executor_project_roles" {
  description = "Project roles needed by the post-bootstrap Terraform executor to manage this foundation."
  type        = set(string)
  default = [
    "roles/artifactregistry.admin",
    "roles/compute.networkAdmin",
    "roles/container.admin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountUser",
    "roles/iam.workloadIdentityPoolAdmin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/serviceusage.serviceUsageAdmin",
  ]
}
