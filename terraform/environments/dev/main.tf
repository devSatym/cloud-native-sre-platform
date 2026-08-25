locals {
  common_labels = merge(
    {
      environment = var.environment
      managed-by  = "terraform"
      platform    = "cloud-native-sre"
    },
    var.labels,
  )

  node_network_tags = ["${var.cluster_name}-node"]

  # These APIs are the minimum needed by the resources in this environment.
  # They intentionally remain enabled on destroy so teardown does not disrupt
  # other project activity or make a later recreate unexpectedly fail.
  required_services = toset([
    "artifactregistry.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "serviceusage.googleapis.com",
    "sts.googleapis.com",
  ])
}

resource "google_project_service" "required" {
  for_each = local.required_services

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

module "network" {
  source = "../../modules/network"

  project_id                    = var.project_id
  region                        = var.region
  network_name                  = var.network_name
  subnetwork_name               = var.subnetwork_name
  subnetwork_cidr               = var.subnetwork_cidr
  pods_secondary_range_name     = var.pods_secondary_range_name
  pods_secondary_cidr           = var.pods_secondary_cidr
  services_secondary_range_name = var.services_secondary_range_name
  services_secondary_cidr       = var.services_secondary_cidr
  node_network_tags             = toset(local.node_network_tags)

  depends_on = [google_project_service.required]
}

module "gke" {
  source = "../../modules/gke"

  project_id                    = var.project_id
  zone                          = var.zone
  cluster_name                  = var.cluster_name
  network_id                    = module.network.network_id
  subnetwork_id                 = module.network.subnetwork_id
  pods_secondary_range_name     = module.network.pods_secondary_range_name
  services_secondary_range_name = module.network.services_secondary_range_name
  node_service_account_id       = var.node_service_account_id
  node_pool_name                = var.node_pool_name
  node_machine_type             = var.node_machine_type
  node_disk_size_gb             = var.node_disk_size_gb
  min_node_count                = var.min_node_count
  max_node_count                = var.max_node_count
  node_network_tags             = toset(local.node_network_tags)
  deletion_protection           = var.deletion_protection
  labels                        = local.common_labels

  depends_on = [google_project_service.required]
}

module "artifact_registry" {
  source = "../../modules/artifact-registry"

  project_id                    = var.project_id
  location                      = var.region
  repository_id                 = var.artifact_registry_repository
  reader_service_account_emails = toset([module.gke.node_service_account_email])
  labels                        = local.common_labels

  depends_on = [google_project_service.required]
}

module "github_wif" {
  source = "../../modules/github-wif"

  project_id                         = var.project_id
  github_repository                  = var.github_repository
  workload_identity_pool_id          = var.workload_identity_pool_id
  workload_identity_pool_provider_id = var.workload_identity_pool_provider_id
  deployer_service_account_id        = var.deployer_service_account_id
  terraform_service_account_id       = var.terraform_service_account_id
  artifact_registry_location         = var.region
  artifact_registry_repository_id    = module.artifact_registry.repository_id

  depends_on = [google_project_service.required]
}
