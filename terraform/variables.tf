variable "project" {
  type = "string"
  default = ""
}

variable "env" {
  type = "string"
  default = "local"
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

variable "service_account_iam_roles" {
  type = "list"

  default = [
    "roles/resourcemanager.projectIamAdmin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountKeyAdmin",
    "roles/iam.serviceAccountTokenCreator",
    "roles/iam.serviceAccountUser",
    "roles/viewer",
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
  default = "n1-standard-1"
}

variable "kubernetes_version" {
  type    = "string"
  default = "1.10.6-gke.1"
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

variable "num_vault_pods" {
  type = "string"
  default = "6"
}
