variable "project_id" {
  description = "Google Cloud project ID that owns the repository."
  type        = string
}

variable "location" {
  description = "Artifact Registry location. Use the same region as GKE for a small dev environment."
  type        = string
}

variable "repository_id" {
  description = "Artifact Registry repository ID. api and payments are image packages within this one Docker repository."
  type        = string
}

variable "description" {
  description = "Description for the Docker repository."
  type        = string
  default     = "Immutable API and Payments images for the Cloud Native SRE Platform."
}

variable "reader_service_account_emails" {
  description = "Service account emails granted repository-scoped Artifact Registry reader access."
  type        = set(string)
  default     = []
}

variable "labels" {
  description = "Labels applied to the repository."
  type        = map(string)
  default     = {}
}
