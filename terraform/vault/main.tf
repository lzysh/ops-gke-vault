# Vault Provider
# https://www.terraform.io/docs/providers/vault
provider "vault" {
  address         = "${var.url}"
  token           = "${var.root_token}"
  skip_tls_verify = "${var.skip_tls_verify}"
}

resource "vault_auth_backend" "gcp_backend" {
  type = "gcp"
}

resource "vault_gcp_auth_backend_role" "gcp_dev_roles" {
  count                  = "${length(var.teams)}"
  type                   = "iam"
  role                   = "${element(var.teams, count.index)}-dev"
  project_id             = "${var.project}"
  bound_service_accounts = ["${element(var.teams, count.index)}-dev@${var.project}.iam.gserviceaccount.com"]
  policies               = ["${element(var.teams, count.index)}-dev"]
  ttl                    = "300"
  max_ttl                = "900"

  depends_on = ["vault_auth_backend.gcp_backend"]
}

resource "vault_gcp_auth_backend_role" "gcp_dev_admins_roles" {
  count                  = "${length(var.teams)}"
  type                   = "iam"
  role                   = "${element(var.teams, count.index)}-dev-admins"
  project_id             = "${var.project}"
  bound_service_accounts = ["${element(var.teams, count.index)}-dev-admins@${var.project}.iam.gserviceaccount.com"]
  policies               = ["${element(var.teams, count.index)}-dev-admins"]
  ttl                    = "300"
  max_ttl                = "900"

  depends_on = ["vault_auth_backend.gcp_backend"]
}

resource "vault_gcp_auth_backend_role" "gcp_vault_admins_role" {
  type                   = "iam"
  role                   = "vault-admins"
  project_id             = "${var.project}"
  bound_service_accounts = ["vault-admins@${var.project}.iam.gserviceaccount.com"]
  policies               = ["${vault_policy.admin_policy.name}"]
  ttl                    = "120"
  max_ttl                = "300"

  depends_on = ["vault_auth_backend.gcp_backend"]
}

resource "vault_gcp_auth_backend_role" "gcp_vault_testing_role" {
  type                   = "iam"
  role                   = "vault-testing"
  project_id             = "${var.project}"
  bound_service_accounts = ["vault-testing@${var.project}.iam.gserviceaccount.com"]
  policies               = ["${vault_policy.testing_policy.name}"]
  ttl                    = "60"
  max_ttl                = "120"

  depends_on = ["vault_auth_backend.gcp_backend"]
}

resource "vault_mount" "kv2" {
  path        = "kv2"
  type        = "kv"
  description = "KV Secrets Engine - Version 2"

  options {
    version = 2
  }
}

resource "vault_mount" "kv" {
  path        = "kv"
  type        = "kv"
  description = "KV Secrets Engine"

  options {
    version = 1
  }
}

resource "vault_generic_secret" "kv_testing_init" {
  path = "${vault_mount.kv.path}/testing/init"

  data_json = <<EOT
{
  "team":   "no-team",
  "lifecycle": "testing"
}
EOT
}

resource "vault_policy" "kv_pre_prod_policies" {
  count = "${length(var.teams)}"
  name  = "${element(var.teams, count.index)}-dev"

  policy = <<EOT
path "${vault_mount.kv.path}/${element(var.teams, count.index)}/pre-prod/*" {
capabilities = ["create", "read", "update", "delete", "list"]
}
path "${vault_mount.kv2.path}/${element(var.teams, count.index)}/pre-prod/*" {
capabilities = ["create", "read", "update", "delete", "list"]
}
path "${vault_mount.kv2.path}/metadata/${element(var.teams, count.index)}/pre-prod/*" {
capabilities = ["read", "list"]
}
EOT
}

resource "vault_policy" "kv_prod_policies" {
  count = "${length(var.teams)}"
  name  = "${element(var.teams, count.index)}-dev-admins"

  policy = <<EOT
path "${vault_mount.kv.path}/${element(var.teams, count.index)}/prod/*" {
capabilities = ["create", "read", "update", "delete", "list"]
}
  
path "${vault_mount.kv2.path}/data/${element(var.teams, count.index)}/prod/*" {
capabilities = ["create", "read", "update", "delete", "list"]
}
path "${vault_mount.kv2.path}/metadata/${element(var.teams, count.index)}/prod/*" {
capabilities = ["read", "list"]
}
EOT
}

resource "vault_policy" "admin_policy" {
  name = "vault-admins"

  policy = <<EOT
path "*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOT
}

resource "vault_policy" "testing_policy" {
  name = "vault-testing"

  policy = <<EOT
path "kv/testing/*"
{
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "kv2/data/testing/*"
{
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "kv2/metadata/testing/*"
{
  capabilities = ["read", "delete", "list"]
}
path "kv2/destroy/testing/*"
{
  capabilities = ["update"]
}
EOT
}
