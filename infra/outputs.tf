output "instance_external_ip" {
  description = "External IP of the homeserver-gcp instance (ephemeral)"
  value       = google_compute_instance.homeserver_gcp.network_interface[0].access_config[0].nat_ip
}

output "instance_name" {
  value = google_compute_instance.homeserver_gcp.name
}

output "image_name" {
  description = "Name of the imported GCE custom image"
  value       = google_compute_image.nixos.name
}

output "ssh_host_key_removal_cmd" {
  description = "Run this after first successful Tailscale join to remove the bootstrap key from metadata"
  value       = "gcloud compute instances remove-metadata ${google_compute_instance.homeserver_gcp.name} --zone=${var.zone} --keys=ssh-host-key-b64"
}
