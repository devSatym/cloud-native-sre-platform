variable "project_id" {
  description = "Google Cloud project ID that owns the cluster."
  type        = string
}

variable "zone" {
  description = "Zonal location for the Standard GKE cluster."
  type        = string
}

variable "cluster_name" {
  description = "Name of the GKE cluster."
  type        = string
}

variable "network_id" {
  description = "Self-link of the VPC network used by GKE."
  type        = string
}

variable "subnetwork_id" {
  description = "Self-link of the regional subnet used by GKE."
  type        = string
}

variable "pods_secondary_range_name" {
  description = "Subnet secondary range name allocated to GKE Pods."
  type        = string
}

variable "services_secondary_range_name" {
  description = "Subnet secondary range name allocated to GKE Services."
  type        = string
}

variable "node_service_account_id" {
  description = "Account ID for the dedicated GKE node service account."
  type        = string
}

variable "node_pool_name" {
  description = "Name for the managed default node pool."
  type        = string
}

variable "node_machine_type" {
  description = "Machine type for the small development node pool."
  type        = string
  default     = "e2-standard-2"
}

variable "node_disk_size_gb" {
  description = "Boot disk size, in GiB, for each node."
  type        = number
  default     = 50

  validation {
    condition     = var.node_disk_size_gb >= 30
    error_message = "node_disk_size_gb must be at least 30 GiB."
  }
}

variable "min_node_count" {
  description = "Minimum number of nodes. Two nodes permit meaningful PDB experiments."
  type        = number
  default     = 2

  validation {
    condition     = var.min_node_count >= 2
    error_message = "min_node_count must be at least 2 for the planned PDB validation."
  }
}

variable "max_node_count" {
  description = "Maximum number of autoscaled nodes."
  type        = number
  default     = 3

  validation {
    condition     = var.max_node_count >= 2
    error_message = "max_node_count must be at least 2."
  }
}

variable "node_network_tags" {
  description = "Network tags applied to all nodes."
  type        = set(string)
}

variable "release_channel" {
  description = "GKE release channel for this development cluster."
  type        = string
  default     = "REGULAR"

  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE"], var.release_channel)
    error_message = "release_channel must be RAPID, REGULAR, or STABLE."
  }
}

variable "deletion_protection" {
  description = "Whether Terraform should protect the cluster from deletion. Keep false for short-lived dev environments."
  type        = bool
  default     = false
}

variable "labels" {
  description = "Labels applied to supported cluster and node resources."
  type        = map(string)
  default     = {}
}
