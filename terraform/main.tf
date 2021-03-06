# Google Cloud Provider
# https://www.terraform.io/docs/providers/google/index.html

provider "google" {
  #  version = "1.17.1"
}

provider "local" {}

provider "kubernetes" {
  #  version  = "1.2"
  host     = "${google_container_cluster.vault_cluster.endpoint}"
  username = "${google_container_cluster.vault_cluster.master_auth.0.username}"
  password = "${google_container_cluster.vault_cluster.master_auth.0.password}"

  client_certificate     = "${base64decode(google_container_cluster.vault_cluster.master_auth.0.client_certificate)}"
  client_key             = "${base64decode(google_container_cluster.vault_cluster.master_auth.0.client_key)}"
  cluster_ca_certificate = "${base64decode(google_container_cluster.vault_cluster.master_auth.0.cluster_ca_certificate)}"
}

# Random ID Resource
# https://www.terraform.io/docs/providers/random/r/id.html
resource "random_id" "random" {
  prefix      = "tf"
  byte_length = "3"
}

# Project Resource
# https://www.terraform.io/docs/providers/google/r/google_project.html

resource "google_project" "vault_project" {
  name            = "${var.prefix}-vault-${random_id.random.hex}-${var.env}"
  project_id      = "${var.prefix}-vault-${random_id.random.hex}-${var.env}"
  billing_account = "${var.billing_id}"
  folder_id       = "folders/${var.folder_id}"
}

# Project Services Resource
# Note: This resource attempts to be the authoritative source on all enabled APIs
# https://www.terraform.io/docs/providers/google/r/google_project_services.html

resource "google_project_services" "vault_apis" {
  project            = "${google_project.vault_project.project_id}"
  disable_on_destroy = false

  services = [
    "dns.googleapis.com",
    "cloudkms.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "container.googleapis.com",
    "containerregistry.googleapis.com",
    "stackdriver.googleapis.com",
    "websecurityscanner.googleapis.com",
    "iam.googleapis.com",

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
    "storage-component.googleapis.com",
  ]
}

# Service Account Resource
# https://www.terraform.io/docs/providers/google/r/google_service_account.html

resource "google_service_account" "vault_jwt_sa" {
  count        = "${length(var.team_sa)}"
  account_id   = "${element(var.team_sa, count.index)}"
  display_name = "Service Account for ${element(var.team_sa, count.index)} Vault JWT keys"
  project      = "${google_project.vault_project.project_id}"

  depends_on = ["google_project_services.vault_apis"]
}

# IAM policy for service account
# https://www.terraform.io/docs/providers/google/r/google_service_account_iam.html

resource "google_service_account_iam_member" "vault_jwt_sa_iam" {
  count              = "${length(var.team_sa)}"
  service_account_id = "projects/${google_project.vault_project.project_id}/serviceAccounts/${element(var.team_sa, count.index)}@${google_project.vault_project.project_id}.iam.gserviceaccount.com"
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "group:${element(var.team_sa, count.index)}@${var.org_domain}"

  depends_on = ["google_service_account.vault_jwt_sa"]
}

resource "google_service_account_iam_member" "vault_jwt_sa_testing_iam" {
  service_account_id = "projects/${google_project.vault_project.project_id}/serviceAccounts/vault-testing@${google_project.vault_project.project_id}.iam.gserviceaccount.com"
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${var.gocd_default_compute_sa}"

  depends_on = ["google_service_account.vault_jwt_sa"]
}

# Service Account Key Resource
# https://www.terraform.io/docs/providers/google/r/google_service_account_key.html

resource "google_service_account_key" "vault_key" {
  service_account_id = "${google_project.vault_project.number}-compute@developer.gserviceaccount.com"

  depends_on = ["google_project_services.vault_apis"]
}

# IAM Policy for Projects Resource
# https://www.terraform.io/docs/providers/google/r/google_project_iam.html#google_project_iam_member

# This allows external dns to modify records in the dns project 

resource "google_project_iam_member" "vault_dns_project_iam" {
  project = "${var.dns_project}"
  role    = "roles/dns.admin"
  member  = "serviceAccount:${google_project.vault_project.number}-compute@developer.gserviceaccount.com"

  depends_on = ["google_project_services.vault_apis"]
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

  lifecycle_rule {
    action {
      type = "Delete"
    }

    condition {
      num_newer_versions = 3
    }
  }

  depends_on = ["google_project_services.vault_apis"]
}

# Storage Bucket IAM Resource
# https://www.terraform.io/docs/providers/google/r/storage_bucket_iam.html#google_storage_bucket_iam_member

resource "google_storage_bucket_iam_member" "vault_bucket_iam" {
  count  = "${length(var.storage_bucket_roles)}"
  bucket = "${google_storage_bucket.vault_bucket.name}"
  role   = "${element(var.storage_bucket_roles, count.index)}"
  member = "serviceAccount:${google_project.vault_project.number}-compute@developer.gserviceaccount.com"

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

# KMS IAM Policy Resource
# https://www.terraform.io/docs/providers/google/r/google_kms_crypto_key_iam_member.html

resource "google_kms_crypto_key_iam_member" "vault_key_iam" {
  count         = "${length(var.kms_crypto_key_roles)}"
  crypto_key_id = "${google_kms_crypto_key.vault_key.id}"
  role          = "${element(var.kms_crypto_key_roles, count.index)}"
  member        = "serviceAccount:${google_project.vault_project.number}-compute@developer.gserviceaccount.com"
}

# Kubernetes Engine (GKE) Resource
# https://www.terraform.io/docs/providers/google/r/container_cluster.html

resource "google_container_cluster" "vault_cluster" {
  name    = "vault-cluster-${var.region}"
  project = "${google_project.vault_project.project_id}"
  region  = "${var.region}"

  min_master_version = "${var.kubernetes_version}"
  node_version       = "${var.kubernetes_version}"
  logging_service    = "${var.kubernetes_logging_service}"
  monitoring_service = "${var.kubernetes_monitoring_service}"

  node_pool {
    name = "default-pool"

    node_config {
      machine_type = "${var.machine_type}"

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
      auto_repair  = "true"
      auto_upgrade = "false"
    }
  }

  depends_on = ["google_project_services.vault_apis"]
}

# Kubernetes Namespace Resource
# https://www.terraform.io/docs/providers/kubernetes/r/namespace.html 

resource "kubernetes_namespace" "vault_ns" {
  metadata {
    name = "vault"
  }

  depends_on = ["google_container_cluster.vault_cluster"]
}

resource "kubernetes_namespace" "external_dns_ns" {
  metadata {
    name = "external-dns"
  }
}

resource "kubernetes_namespace" "cert_manager_ns" {
  metadata {
    name = "cert-manager"
  }
}

# Kubernetes Config Map Resource
# https://www.terraform.io/docs/providers/kubernetes/r/config_map.html

resource "kubernetes_config_map" "vault_config_map" {
  metadata {
    name      = "vault"
    namespace = "${kubernetes_namespace.vault_ns.metadata.0.name}"
  }

  data {
    gcs_bucket_name = "${google_storage_bucket.vault_bucket.name}"
    kms_key_id      = "${google_kms_crypto_key.vault_key.id}"
  }
}

# Template File Data Source
# https://www.terraform.io/docs/providers/template/d/file.html

data "template_file" "external_dns" {
  template = "${file("${path.module}/../kubernetes/external-dns.yaml")}"

  vars {
    dns_project = "${var.dns_project}"
  }
}

data "template_file" "cert_manager" {
  template = "${file("${path.module}/../kubernetes/cert-manager.yaml")}"

  vars {
    lets_encrypt_api   = "${var.lets_encrypt_api}"
    lets_encrypt_email = "${var.lets_encrypt_email}"
  }
}

data "template_file" "temp_tls" {
  template = "${file("${path.module}/../kubernetes/temp-tls.yaml")}"
}

data "template_file" "vault" {
  template = "${file("${path.module}/../kubernetes/vault.yaml")}"

  vars {
    num_vault_servers = "${var.num_vault_servers}"
    domain            = "${var.domain}"
    host              = "${var.host}"
  }
}

# Null Resource
# https://www.terraform.io/docs/providers/null/resource.html

resource "null_resource" "clusterrole_binding" {
  provisioner "local-exec" {
    command = <<EOF
gcloud container clusters get-credentials "${google_container_cluster.vault_cluster.name}" --region="${google_container_cluster.vault_cluster.zone}" --project="${google_container_cluster.vault_cluster.project}"

CONTEXT="gke_${google_container_cluster.vault_cluster.project}_${google_container_cluster.vault_cluster.zone}_${google_container_cluster.vault_cluster.name}"

ACCOUNT=$(gcloud info --format='value(config.account)')

kubectl create --context="$CONTEXT" clusterrolebinding cluster-admin-binding --clusterrole cluster-admin --user $ACCOUNT
EOF
  }
}

resource "null_resource" "external_dns" {
  triggers {
    config_sha1 = "${sha1(data.template_file.external_dns.rendered)}"
  }

  provisioner "local-exec" {
    command = <<EOF
gcloud container clusters get-credentials "${google_container_cluster.vault_cluster.name}" --region="${google_container_cluster.vault_cluster.zone}" --project="${google_container_cluster.vault_cluster.project}"

CONTEXT="gke_${google_container_cluster.vault_cluster.project}_${google_container_cluster.vault_cluster.zone}_${google_container_cluster.vault_cluster.name}"

echo '${data.template_file.external_dns.rendered}' | kubectl apply --context="$CONTEXT" -f -

for i in $(seq -s " " 1 15); do
  sleep $i
  if [ $(kubectl get pod --namespace=external-dns | grep external-dns | grep Running | wc -l) -eq 1 ]; then
    echo "Pods are running"
    exit 0
  fi
done

echo "Pods are not ready after 2m"
exit 1
    EOF
  }

  depends_on = [
    "kubernetes_namespace.external_dns_ns",
    "null_resource.clusterrole_binding",
  ]
}

resource "null_resource" "cert_manager" {
  triggers {
    config_sha1 = "${sha1(data.template_file.cert_manager.rendered)}"
  }

  provisioner "local-exec" {
    command = <<EOF
gcloud container clusters get-credentials "${google_container_cluster.vault_cluster.name}" --region="${google_container_cluster.vault_cluster.zone}" --project="${google_container_cluster.vault_cluster.project}"

CONTEXT="gke_${google_container_cluster.vault_cluster.project}_${google_container_cluster.vault_cluster.zone}_${google_container_cluster.vault_cluster.name}"

echo '${data.template_file.cert_manager.rendered}' | kubectl apply --context="$CONTEXT" -f -

for i in $(seq -s " " 1 15); do
  sleep $i
  if [ $(kubectl get pod --namespace=cert-manager | grep cert-manager | grep Running | wc -l) -eq 1 ]; then
    echo "Pods are running"
    sleep 10
    exit 0
  fi
done

echo "Pods are not ready after 2m"
exit 1
    EOF
  }

  depends_on = [
    "kubernetes_namespace.cert_manager_ns",
    "null_resource.clusterrole_binding",
  ]
}

resource "null_resource" "temp_tls" {
  provisioner "local-exec" {
    command = <<EOF
gcloud container clusters get-credentials "${google_container_cluster.vault_cluster.name}" --region="${google_container_cluster.vault_cluster.zone}" --project="${google_container_cluster.vault_cluster.project}"

CONTEXT="gke_${google_container_cluster.vault_cluster.project}_${google_container_cluster.vault_cluster.zone}_${google_container_cluster.vault_cluster.name}"

echo '${data.template_file.temp_tls.rendered}' | kubectl apply --context="$CONTEXT" -f -
    sleep 10
    EOF
  }

  depends_on = [
    "null_resource.cert_manager",
  ]
}

resource "null_resource" "vault" {
  triggers {
    config_sha1 = "${sha1(data.template_file.vault.rendered)}"
  }

  provisioner "local-exec" {
    command = <<EOF
gcloud container clusters get-credentials "${google_container_cluster.vault_cluster.name}" --region="${google_container_cluster.vault_cluster.zone}" --project="${google_container_cluster.vault_cluster.project}"

CONTEXT="gke_${google_container_cluster.vault_cluster.project}_${google_container_cluster.vault_cluster.zone}_${google_container_cluster.vault_cluster.name}"

echo '${data.template_file.vault.rendered}' | kubectl apply --context="$CONTEXT" -f -

for i in $(seq -s " " 1 15); do
  sleep $i
  if [ $(kubectl get pod --namespace=vault | grep vault | grep Running | wc -l) -eq ${var.num_vault_servers} ]; then
    echo "Pods are Running"
    success=0
    for i in $(seq -s " " 1 50); do
      sleep $i
      if [ $(curl -sk -o /dev/null -w "%{http_code}" \
      https://${var.host}.${var.domain}/v1/sys/health?standbyok=true) -eq 200 ]; then
        success=`expr $success + 1`
        if [ "$${success}" = 5 ]; then
          echo "Vault is Running"
          exit 0
        fi
      fi
    done
    echo "Vault is not ready"
    exit 1
  fi
done
echo "Pods are not ready"
exit
    EOF
  }

  depends_on = [
    "kubernetes_namespace.vault_ns",
    "null_resource.external_dns",
    "null_resource.temp_tls",
  ]
}

# Download the encrypted root token to disk
data "google_storage_object_signed_url" "root-token" {
  bucket = "${google_storage_bucket.vault_bucket.name}"
  path   = "root-token.enc"

  credentials = "${base64decode(google_service_account_key.vault_key.private_key)}"
}

# Download the encrypted file
data "http" "root-token" {
  url = "${data.google_storage_object_signed_url.root-token.signed_url}"

  depends_on = ["null_resource.vault"]
}

# Decrypt the secret
data "google_kms_secret" "root-token" {
  crypto_key = "${google_kms_crypto_key.vault_key.id}"
  ciphertext = "${data.http.root-token.body}"
}

output "token_decrypt_command" {
  sensitive = true
  value     = "gsutil cat gs://${google_storage_bucket.vault_bucket.name}/root-token.enc | base64 --decode | gcloud kms decrypt --project ${google_project.vault_project.project_id} --location global --keyring ${google_kms_key_ring.vault_kms.name} --key ${google_kms_crypto_key.vault_key.name} --ciphertext-file - --plaintext-file -"
}

output "root_token" {
  sensitive = true
  value     = "${data.google_kms_secret.root-token.plaintext}"
}

output "project" {
  value = "${google_project.vault_project.project_id}"
}

output "url" {
  value = "https://${var.host}.${var.domain}"
}
