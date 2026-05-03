terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  # Local state by default. Migrate to a GCS backend once the bucket exists:
  #
  # backend "gcs" {
  #   bucket = "<your-project>-homeserver-gcp-tfstate"
  #   prefix = "terraform/state"
  # }
}

provider "google" {
  project = var.gcp_project
  region  = var.region
}
