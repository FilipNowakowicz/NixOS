locals {
  name = "homeserver-gcp"
}

# ── Image storage ────────────────────────────────────────────────────────────

resource "google_storage_bucket" "images" {
  name                        = "${var.gcp_project}-${local.name}-images"
  location                    = var.region
  force_destroy               = true
  uniform_bucket_level_access = true

  lifecycle_rule {
    condition { age = 60 }
    action { type = "Delete" }
  }
}

resource "google_storage_bucket_object" "nixos_image" {
  name   = "${local.name}-${var.image_version}.raw.tar.gz"
  bucket = google_storage_bucket.images.name
  source = var.image_path
}

# ── Custom GCE image ─────────────────────────────────────────────────────────

resource "google_compute_image" "nixos" {
  name        = "${local.name}-${replace(var.image_version, ".", "-")}"
  description = "NixOS ${local.name}"

  raw_disk {
    source = "https://storage.googleapis.com/${google_storage_bucket.images.name}/${google_storage_bucket_object.nixos_image.name}"
  }

  guest_os_features {
    type = "VIRTIO_SCSI_MULTIQUEUE"
  }

  timeouts {
    create = "15m"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ── Firewall ─────────────────────────────────────────────────────────────────

resource "google_compute_firewall" "tailscale" {
  name        = "${local.name}-tailscale"
  network     = "default"
  description = "Allow Tailscale UDP inbound for ${local.name}"

  allow {
    protocol = "udp"
    ports    = ["41641"]
  }

  target_tags   = [local.name]
  source_ranges = ["0.0.0.0/0", "::/0"]
}

# ── VM instance ──────────────────────────────────────────────────────────────

resource "google_compute_instance" "homeserver_gcp" {
  name         = local.name
  machine_type = var.machine_type
  zone         = var.zone
  tags         = [local.name]

  boot_disk {
    initialize_params {
      image = google_compute_image.nixos.self_link
      size  = var.disk_size_gb
      type  = "pd-ssd"
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  metadata = {
    # Pre-baked SSH host key for sops bootstrap — consumed by the
    # injectGceSshHostKey activation script on first boot.
    # The key is only needed until Tailscale is up; remove it afterwards:
    #   gcloud compute instances remove-metadata homeserver-gcp --keys=ssh-host-key-b64
    ssh-host-key-b64 = var.ssh_host_key_b64

    # Enable GCE serial console login for emergency recovery.
    serial-port-enable = "TRUE"
  }

  # Boot disk image is managed by image_version; don't let tofu replace the
  # running VM on every image rebuild — config updates use deploy-rs instead.
  lifecycle {
    ignore_changes = [boot_disk[0].initialize_params[0].image]
  }
}
