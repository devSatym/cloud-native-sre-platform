variable "project_id" {
  description = "Google Cloud project ID that owns the network."
  type        = string
}

variable "region" {
  description = "Region for the subnet and its secondary ranges."
  type        = string
}

variable "network_name" {
  description = "Name for the custom VPC network."
  type        = string
}

variable "subnetwork_name" {
  description = "Name for the regional GKE subnet."
  type        = string
}

variable "subnetwork_cidr" {
  description = "Primary IPv4 CIDR for GKE nodes."
  type        = string

  validation {
    condition     = can(cidrhost(var.subnetwork_cidr, 0))
    error_message = "subnetwork_cidr must be a valid IPv4 CIDR range."
  }
}

variable "pods_secondary_range_name" {
  description = "Name of the subnet secondary range allocated to GKE Pods."
  type        = string
}

variable "pods_secondary_cidr" {
  description = "IPv4 CIDR for GKE Pods."
  type        = string

  validation {
    condition     = can(cidrhost(var.pods_secondary_cidr, 0))
    error_message = "pods_secondary_cidr must be a valid IPv4 CIDR range."
  }
}

variable "services_secondary_range_name" {
  description = "Name of the subnet secondary range allocated to GKE Services."
  type        = string
}

variable "services_secondary_cidr" {
  description = "IPv4 CIDR for GKE Services."
  type        = string

  validation {
    condition     = can(cidrhost(var.services_secondary_cidr, 0))
    error_message = "services_secondary_cidr must be a valid IPv4 CIDR range."
  }
}

variable "node_network_tags" {
  description = "Network tags applied to GKE nodes and targeted by the health-check rule."
  type        = set(string)
}

variable "health_check_source_ranges" {
  description = "Google Cloud Load Balancer health-check source ranges allowed to GKE NodePorts."
  type        = set(string)
  default = [
    "35.191.0.0/16",
    "130.211.0.0/22",
  ]

  validation {
    condition     = alltrue([for cidr in var.health_check_source_ranges : can(cidrhost(cidr, 0))])
    error_message = "health_check_source_ranges must contain only valid IPv4 CIDR ranges."
  }
}
