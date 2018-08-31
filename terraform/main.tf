# Google Cloud Provider
# https://www.terraform.io/docs/providers/google/index.html

provider "google" {
  version = "1.17.1"
}

provider "random" {
  version = "2.0"
}

# Ramdom ID Resource
# https://www.terraform.io/docs/providers/random/r/id.html

resource "random_id" "random" {
  byte_length = "4"
}

# Project Resource
# https://www.terraform.io/docs/providers/google/r/google_project.html

resource "google_project" "vault_project" {
  name = "${var.project}-${random_id.random.hex}-${var.env}"
  project_id = "${var.project}-${random_id.random.hex}-${var.env}"
  billing_account = "${var.billing_id}"
  folder_id  = "folders/${var.folder_id}"
}

# Project Services Resource
# Note: This resource attempts to be the authoritative source on all enabled APIs
# https://www.terraform.io/docs/providers/google/r/google_project_services.html

resource "google_project_services" "vault_apis" {
 project = "${google_project.vault_project.project_id}"
 disable_on_destroy = false
 services = [
   "cloudkms.googleapis.com",
   "container.googleapis.com",
   "containerregistry.googleapis.com",
   # Enabled by a resource
   "compute.googleapis.com",
   "pubsub.googleapis.com",
   "oslogin.googleapis.com",
   # Default APIs
   "bigquery-json.googleapis.com",
   "cloudapis.googleapis.com",
   "clouddebugger.googleapis.com",
   "cloudtrace.googleapis.com",
   "datastore.googleapis.com",
   "logging.googleapis.com",
   "monitoring.googleapis.com",
   "servicemanagement.googleapis.com",
   "serviceusage.googleapis.com",
   "sql-component.googleapis.com",
   "storage-api.googleapis.com",
   "storage-component.googleapis.com"
 ]
}

# IAM Policy for Projects Resource
# Note: Authoritative for a given role
# https://www.terraform.io/docs/providers/google/r/google_project_iam.html#google_project_iam_binding

resource "google_project_iam_binding" "terraform_iam_owner" {
  project = "${google_project.vault_project.project_id}"
  role = "roles/owner"
  members = [
    "serviceAccount:terraform@ops-tools-prod.iam.gserviceaccount.com"
  ]
}

# Service Account Resource
# https://www.terraform.io/docs/providers/google/r/google_service_account.html

resource "google_service_account" "vault_sa" {
  account_id   = "vault-${random_id.random.hex}"
  display_name = "Vault Service Account"
  project      = "${google_project.vault_project.project_id}"
}

# Service Account Key Resource
# https://www.terraform.io/docs/providers/google/r/google_service_account_key.html

resource "google_service_account_key" "vault_key" {
  service_account_id = "${google_service_account.vault_sa.name}"
}

# IAM Policy for Projects Resource
# https://www.terraform.io/docs/providers/google/r/google_project_iam.html#google_project_iam_member

resource "google_project_iam_member" "vault_iam" {
  count   = "${length(var.service_account_iam_roles)}"
  project = "${google_project.vault_project.project_id}"
  role    = "${element(var.service_account_iam_roles, count.index)}"
  member  = "serviceAccount:${google_service_account.vault_sa.email}"
}

# Storage Bucket Resource
# https://www.terraform.io/docs/providers/google/r/storage_bucket.html

resource "google_storage_bucket" "vault_bucket" {
  name          = "${google_project.vault_project.project_id}-vault-storage"
  project       = "${google_project.vault_project.project_id}"
  force_destroy = true
  storage_class = "MULTI_REGIONAL"

  versioning {
    enabled = true
  }

  depends_on = ["google_project_services.vault_apis"]
}

# KMS Resource
# https://www.terraform.io/docs/providers/google/r/google_kms_key_ring.html

resource "google_kms_key_ring" "vault_kms" {
  name     = "vault"
  location = "global"
  project  = "${google_project.vault_project.project_id}"

  depends_on = ["google_project_services.vault_apis"]
}

# KMS CryptoKey Resource
# https://www.terraform.io/docs/providers/google/r/google_kms_crypto_key.html

resource "google_kms_crypto_key" "vault_key" {
  name            = "vault-init"
  key_ring        = "${google_kms_key_ring.vault_kms.id}"
  rotation_period = "604800s"
}

# Grant service account access to the key
resource "google_kms_crypto_key_iam_member" "vault_key_iam" {
  count         = "${length(var.kms_crypto_key_roles)}"
  crypto_key_id = "${google_kms_crypto_key.vault_key.id}"
  role          = "${element(var.kms_crypto_key_roles, count.index)}"
  member        = "serviceAccount:${google_service_account.vault_sa.email}"
}

// Google Kubernetes Engine (GKE) cluster
// https://www.terraform.io/docs/providers/google/r/container_cluster.html

resource "google_container_cluster" "vault_name" {
  name    = "vault-cluster-${var.region}"
  project = "${google_project.vault_project.project_id}"
  region    = "${var.region}"

  min_master_version = "${var.kubernetes_version}"
  node_version       = "${var.kubernetes_version}"
  logging_service    = "${var.kubernetes_logging_service}"
  monitoring_service = "${var.kubernetes_monitoring_service}"

  node_pool {
    name = "default-pool"
    node_config {
      machine_type    = "${var.instance_type}"
      service_account = "${google_service_account.vault_sa.email}"

      oauth_scopes = [
        "https://www.googleapis.com/auth/cloud-platform",
        "https://www.googleapis.com/auth/compute",
        "https://www.googleapis.com/auth/devstorage.read_write",
        "https://www.googleapis.com/auth/logging.write",
        "https://www.googleapis.com/auth/monitoring",
      ]
    }
    
    initial_node_count = "${var.node_count}"
 
    autoscaling {
      min_node_count = "${var.min_node_count}"
      max_node_count = "${var.max_node_count}"
    }
    
    management {
      auto_repair = "true"
      auto_upgrade = "false"
    }
  }

  depends_on = ["google_project_services.vault_apis"]
}
