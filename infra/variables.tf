variable "gcp_project" {
  type        = string
  description = "GCP project ID (find in GCP console or: gcloud config get-value project)"
}

variable "region" {
  type        = string
  description = "GCP region (us-central1 is covered by free tier)"
  default     = "us-central1"
}

variable "zone" {
  type        = string
  description = "GCP zone within the region"
  default     = "us-central1-a"
}

variable "machine_type" {
  type        = string
  description = "GCE machine type (e2-medium = 2 vCPU, 4 GB RAM; sufficient for full LGTM stack)"
  default     = "e2-medium"
}

variable "disk_size_gb" {
  type        = number
  description = "Boot disk size in GB"
  default     = 50
}

variable "image_path" {
  type        = string
  description = "Local path to the NixOS GCE image (*.raw.tar.gz) produced by nix build"
}

variable "image_version" {
  type        = string
  description = "Version tag for the uploaded image — change this to force a new upload"
}

variable "ssh_host_key_b64" {
  type        = string
  sensitive   = true
  description = "Base64-encoded SSH host private key injected via instance metadata for sops bootstrap"
}
