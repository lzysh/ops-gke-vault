variable "url" {
  type = "string"
}

variable "root_token" {
  type = "string"
}

variable "skip_tls_verify" {
  type    = "string"
  default = "true"
}

variable "teams" {
  type = "list"

  default = [
    "team-a",
    "team-b",
  ]
}

variable "project" {
  type = "string"
}
