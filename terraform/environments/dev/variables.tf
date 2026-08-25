variable "project_id" {
  description = "Billing-enabled Google Cloud project ID for the development foundation."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be a valid Google Cloud project ID."
  }
}

variable "region" {
  description = "Region for the subnet and Artifact Registry repository."
  type        = string
}

variable "zone" {
  description = "Zone for the cost-conscious Standard GKE development cluster."
  type        = string
}

variable "github_repository" {
  description = "Exact GitHub repository allowed to use the GitHub OIDC provider, in owner/repository form."
  type        = string

  validation {
    condition     = can(regex("^[^/]+/[^/]+$", var.github_repository))
    error_message = "github_repository must use the owner/repository form."
  }
}

variable "environment" {
  description = "Environment name included in labels and default resource names."
  type        = string
  default     = "dev"
}

variable "network_name" {
  description = "Name of the custom VPC."
  type        = string
  default     = "sre-dev-vpc"
}

variable "subnetwork_name" {
  description = "Name of the regional GKE subnet."
  type        = string
  default     = "sre-dev-gke-subnet"
}

variable "subnetwork_cidr" {
  description = "Primary IPv4 CIDR for GKE nodes."
  type        = string
  default     = "10.20.0.0/20"
}

variable "pods_secondary_range_name" {
  description = "Name of the GKE Pod secondary range."
  type        = string
  default     = "gke-pods"
}

variable "pods_secondary_cidr" {
  description = "IPv4 CIDR for GKE Pods."
  type        = string
  default     = "10.24.0.0/16"
}

variable "services_secondary_range_name" {
  description = "Name of the GKE Service secondary range."
  type        = string
  default     = "gke-services"
}

variable "services_secondary_cidr" {
  description = "IPv4 CIDR for GKE Services."
  type        = string
  default     = "10.28.0.0/20"
}

variable "cluster_name" {
  description = "Name of the zonal Standard GKE cluster."
  type        = string
  default     = "sre-dev-gke"
}

variable "node_pool_name" {
  description = "Name of the managed development node pool."
  type        = string
  default     = "primary"
}

variable "node_service_account_id" {
  description = "Account ID for the dedicated GKE node identity."
  type        = string
  default     = "sre-gke-nodes"
}

variable "node_machine_type" {
  description = "Machine type for development nodes."
  type        = string
  default     = "e2-standard-2"
}

variable "node_disk_size_gb" {
  description = "Node boot disk size in GiB."
  type        = number
  default     = 50
}

variable "min_node_count" {
  description = "Minimum node-pool size; must remain at least 2 for PDB experiments."
  type        = number
  default     = 2
}

variable "max_node_count" {
  description = "Maximum node-pool autoscaling size."
  type        = number
  default     = 3
}

variable "artifact_registry_repository" {
  description = "One Docker Artifact Registry repository containing api and payments image packages."
  type        = string
  default     = "sre-images-dev"
}

variable "workload_identity_pool_id" {
  description = "Short ID for the GitHub Actions workload identity pool."
  type        = string
  default     = "github-actions"
}

variable "workload_identity_pool_provider_id" {
  description = "Short ID for the GitHub Actions OIDC provider."
  type        = string
  default     = "github"
}

variable "deployer_service_account_id" {
  description = "Account ID for the low-privilege GitHub deployer identity."
  type        = string
  default     = "github-deployer"
}

variable "terraform_service_account_id" {
  description = "Account ID for the guarded GitHub Terraform executor identity."
  type        = string
  default     = "terraform-executor"
}

variable "deletion_protection" {
  description = "Set true only when this development cluster should be protected from Terraform destroy."
  type        = bool
  default     = false
}

variable "labels" {
  description = "Additional labels applied to supported GCP resources."
  type        = map(string)
  default     = {}
}
