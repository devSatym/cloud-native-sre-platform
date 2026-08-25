resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = var.workload_identity_pool_id
  display_name              = "GitHub Actions"
  description               = "Keyless GitHub Actions OIDC federation for the Cloud Native SRE Platform."
  disabled                  = false
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = var.workload_identity_pool_provider_id
  display_name                       = "GitHub Actions OIDC"
  description                        = "Only OIDC tokens from the configured GitHub repository can authenticate."

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.actor"            = "assertion.actor"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
  }

  # The provider condition is evaluated before service-account impersonation.
  # It prevents a token issued for any other GitHub repository from being used.
  attribute_condition = "assertion.repository == \"${var.github_repository}\""

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "deployer" {
  project      = var.project_id
  account_id   = var.deployer_service_account_id
  display_name = "GitHub deployer"
  description  = "Keyless GitHub Actions identity for Artifact Registry pushes and GKE deployments."
}

resource "google_service_account" "terraform" {
  project      = var.project_id
  account_id   = var.terraform_service_account_id
  display_name = "GitHub Terraform executor"
  description  = "Keyless GitHub Actions identity used only by the guarded Terraform workflow after bootstrap."
}

locals {
  repository_principal_set = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repository}"
}

resource "google_service_account_iam_member" "deployer_workload_identity_user" {
  service_account_id = google_service_account.deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = local.repository_principal_set
}

resource "google_service_account_iam_member" "terraform_workload_identity_user" {
  service_account_id = google_service_account.terraform.name
  role               = "roles/iam.workloadIdentityUser"
  member             = local.repository_principal_set
}

# The deployer can write only this project's application image repository and
# use GKE developer permissions for cluster credentials/Kubernetes deployment.
resource "google_artifact_registry_repository_iam_member" "deployer_writer" {
  project    = var.project_id
  location   = var.artifact_registry_location
  repository = var.artifact_registry_repository_id
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.deployer.email}"
}

resource "google_project_iam_member" "deployer_gke_developer" {
  project = var.project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.deployer.email}"
}

# This executor is intentionally separate from the application deployer. These
# roles are needed only because Terraform owns project IAM, WIF, networking,
# GKE, and Artifact Registry. Run it from a protected, manually approved
# Terraform apply workflow after the one-time bootstrap described in the README.
resource "google_project_iam_member" "terraform_executor" {
  for_each = var.terraform_executor_project_roles

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.terraform.email}"
}
