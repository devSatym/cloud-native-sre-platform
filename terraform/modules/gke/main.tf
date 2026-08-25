resource "google_service_account" "nodes" {
  project      = var.project_id
  account_id   = var.node_service_account_id
  display_name = "GKE nodes for ${var.cluster_name}"
  description  = "Dedicated node identity for the ${var.cluster_name} GKE cluster."
}

# This predefined role grants the permissions a GKE node needs without using
# the project's broad default Compute Engine service account.
resource "google_project_iam_member" "nodes_default_permissions" {
  project = var.project_id
  role    = "roles/container.defaultNodeServiceAccount"
  member  = "serviceAccount:${google_service_account.nodes.email}"
}

resource "google_container_cluster" "this" {
  project  = var.project_id
  name     = var.cluster_name
  location = var.zone

  network    = var.network_id
  subnetwork = var.subnetwork_id

  # A separately managed node pool makes autoscaling and lifecycle controls
  # explicit. GKE requires an initial count while the default pool is removed.
  remove_default_node_pool = true
  initial_node_count       = 1

  networking_mode = "VPC_NATIVE"

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_secondary_range_name
    services_secondary_range_name = var.services_secondary_range_name
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Calico network-policy enforcement keeps the GKE deployment compatible
  # with the Kubernetes NetworkPolicies rendered by the Helm release.
  network_policy {
    enabled = true
  }

  addons_config {
    network_policy_config {
      disabled = false
    }
  }

  release_channel {
    channel = var.release_channel
  }

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
  }

  enable_shielded_nodes = true
  resource_labels       = var.labels
  deletion_protection   = var.deletion_protection
}

resource "google_container_node_pool" "primary" {
  project  = var.project_id
  name     = var.node_pool_name
  location = var.zone
  cluster  = google_container_cluster.this.name

  # Start at the PDB-capable minimum; autoscaling can add only one modest
  # development node when workloads need it.
  node_count = var.min_node_count

  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = var.node_machine_type
    disk_type       = "pd-balanced"
    disk_size_gb    = var.node_disk_size_gb
    image_type      = "COS_CONTAINERD"
    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    labels          = var.labels
    tags            = var.node_network_tags

    metadata = {
      disable-legacy-endpoints = "true"
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }

  depends_on = [google_project_iam_member.nodes_default_permissions]

  lifecycle {
    # Do not scale the pool back to its initial size on a later Terraform apply
    # after the cluster autoscaler has added the third development node.
    ignore_changes = [node_count]

    precondition {
      condition     = var.max_node_count >= var.min_node_count
      error_message = "max_node_count must be greater than or equal to min_node_count."
    }
  }
}
