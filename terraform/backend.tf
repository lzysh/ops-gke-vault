terraform {
  backend "gcs" {
    prefix = "terraform.tfstate"
  }
}
