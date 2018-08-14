data "google_compute_image" "go" {
  name    = "${var.gcp_image}"
  project = "${var.gcp_project}"
}

resource "google_compute_instance_template" "iam_instance_template" {
  name  = "go-iam-template"
  machine_type = "n1-standard-1"
  region       = "${var.gcp_region}"

  disk {
    source_image = "${data.google_compute_image.go.self_link}"
  }

  network_interface {
    network = "default"
    access_config {}
  }

  lifecycle {
    create_before_destroy = true
  }

  service_account {
    email  = "${google_service_account.go.email}"
    scopes = ["cloud-platform"]
  }

  metadata {
    sshKeys = "ubuntu:${tls_private_key.go.public_key_openssh}"
  }

  tags = ["go-iam-apps"]

  metadata_startup_script = <<SCRIPT
cat << EOF > /app/config.toml
[database]
host="${var.postgres_host}"
port="${var.postgres_port}"
name="${var.postgres_database}"
mount="database"
role="order"
[vault]
host="${var.vault_host}"
mount="gcp-iam"
port="${var.vault_port}"
scheme="${var.vault_scheme}"
authentication="gcp-iam"
role="order"
credential="${google_service_account.order.email}"
EOF
systemctl enable go.service
service go restart
SCRIPT

}

resource "google_compute_instance_group_manager" "iam_group_manager" {
  name               = "go-iam-apps"
  instance_template  = "${google_compute_instance_template.iam_instance_template.self_link}"
  base_instance_name = "go-iam"
  zone               = "${var.gcp_zone}"
  target_size        = "${var.gcp_instances}"

  named_port {
    name = "go"
    port = 3000
  }

}


resource "google_compute_instance_template" "gce_instance_template" {
  name  = "go-gce-template"
  machine_type = "n1-standard-1"
  region       = "${var.gcp_region}"

  disk {
    source_image = "${data.google_compute_image.go.self_link}"
  }

  network_interface {
    network = "default"
    access_config {}
  }

  lifecycle {
    create_before_destroy = true
  }

  service_account {
    scopes = ["cloud-platform"]
  }

  metadata {
    sshKeys = "ubuntu:${tls_private_key.go.public_key_openssh}"
  }

  tags = ["go-gce-apps"]

  metadata_startup_script = <<SCRIPT
cat << EOF > /app/config.toml
[database]
host="${var.postgres_host}"
port="${var.postgres_port}"
name="${var.postgres_database}"
mount="database"
role="order"
[vault]
host="${var.vault_host}"
mount="gcp-gce"
port="${var.vault_port}"
scheme="${var.vault_scheme}"
authentication="gcp-gce"
role="order"
EOF
systemctl enable go.service
service go restart
SCRIPT

}

resource "google_compute_instance_group_manager" "gce_group_manager" {
  name               = "go-gce-apps"
  instance_template  = "${google_compute_instance_template.gce_instance_template.self_link}"
  base_instance_name = "go-gce"
  zone               = "${var.gcp_zone}"
  target_size        = "${var.gcp_instances}"

  named_port {
    name = "go"
    port = 3000
  }
}
