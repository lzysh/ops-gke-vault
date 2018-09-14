variable "project" {
  type = "string"
}

variable "billing_id" {
  type = "string"
}

variable "folder_id" {
  type = "string"
}

variable "region" {
  type = "string"
  default = "us-east4"
}

variable "service_account_tools_iam_roles" {
  type = "list"

  default = [
    "roles/storage.objectViewer",
    "roles/dns.admin",
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

variable "instance_type" {
  type    = "string"
  default = "n1-standard-2"
}

variable "kubernetes_version" {
  type    = "string"
  default = "1.10.7-gke.1"
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
  default = "4"
}

variable "node_count" {
  type    = "string"
  default = "1"
}

variable "num_vault_servers" {
  type = "string"
  default = "3"
}

variable "domain" {
  type = "string"
}

variable "tools_project" {
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
  default = "no-reply@lzy.sh"
}
