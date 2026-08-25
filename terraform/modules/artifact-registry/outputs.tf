output "repository_id" {
  description = "Short Artifact Registry repository ID for CI variables."
  value       = google_artifact_registry_repository.images.repository_id
}

output "repository_name" {
  description = "Fully qualified Artifact Registry repository resource name."
  value       = google_artifact_registry_repository.images.name
}

output "repository_url" {
  description = "Docker repository base URL. Append /api:<git-sha> or /payments:<git-sha>."
  value       = "${var.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.images.repository_id}"
}

output "api_image_repository" {
  description = "Base image reference for the API package; CI must append an immutable Git SHA tag."
  value       = "${var.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.images.repository_id}/api"
}

output "payments_image_repository" {
  description = "Base image reference for the Payments package; CI must append an immutable Git SHA tag."
  value       = "${var.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.images.repository_id}/payments"
}
