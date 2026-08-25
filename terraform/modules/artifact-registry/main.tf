resource "google_artifact_registry_repository" "images" {
  project       = var.project_id
  location      = var.location
  repository_id = var.repository_id
  description   = var.description
  format        = "DOCKER"
  labels        = var.labels
}

# GKE nodes need only pull access to this repository. The GitHub deployer gets
# writer access in the github-wif module once its service account exists.
resource "google_artifact_registry_repository_iam_member" "node_readers" {
  for_each = var.reader_service_account_emails

  project    = var.project_id
  location   = var.location
  repository = google_artifact_registry_repository.images.repository_id
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${each.value}"
}
