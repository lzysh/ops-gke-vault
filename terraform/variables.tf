variable "env" {
  type = "string"
}

variable "prefix" {
  type = "string"
}

variable "billing_id" {
  type = "string"
}

variable "folder_id" {
  type = "string"
}

variable "region" {
  type    = "string"
  default = "us-east4"
}

variable "vault_jwt_sa_iam_roles" {
  type = "list"

  default = [
    "roles/iam.serviceAccountTokenCreator",
  ]
}

variable "storage_bucket_roles" {
  type = "list"

  default = [
    "roles/storage.legacyBucketReader",
    "roles/storage.objectAdmin",
  ]
}

variable "kms_crypto_key_roles" {
  type = "list"

  default = [
    "roles/cloudkms.cryptoKeyEncrypterDecrypter",
  ]
}

variable "machine_type" {
  type    = "string"
  default = "n1-standard-1"
}

variable "kubernetes_version" {
  type    = "string"
  default = "1.10.7-gke.6"
}

variable "kubernetes_logging_service" {
  type    = "string"
  default = "logging.googleapis.com/kubernetes"
}

variable "kubernetes_monitoring_service" {
  type    = "string"
  default = "monitoring.googleapis.com/kubernetes"
}

variable "min_node_count" {
  type    = "string"
  default = "1"
}

variable "max_node_count" {
  type    = "string"
  default = "3"
}

variable "node_count" {
  type    = "string"
  default = "1"
}

variable "num_vault_servers" {
  type    = "string"
  default = "1"
}

variable "domain" {
  type = "string"
}

variable "dns_project" {
  type = "string"
}

variable "host" {
  type = "string"
}

variable "lets_encrypt_api" {
  type = "string"

  # Prod: acme-v02.api.letsencrypt.org
  # Stage: acme-staging-v02.api.letsencrypt.org
  default = "acme-staging-v02.api.letsencrypt.org"
}

variable "lets_encrypt_email" {
  type = "string"
}

variable "org_domain" {
  type = "string"
}

variable "gocd_default_compute_sa" {
  type = "string"
}

variable "team_sa" {
  type = "list"

  default = [
    "team-a-dev",
    "team-a-dev-admins",
    "team-b-dev",
    "team-b-dev-admins",
    "vault-admins",
    "vault-testing",
  ]
}
