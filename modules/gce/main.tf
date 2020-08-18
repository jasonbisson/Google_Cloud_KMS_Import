/**
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

###############
# Data Sources
###############
data "google_compute_image" "image" {
  project = "${var.source_image != "" ? var.source_image_project : "debian-cloud"}"
  name    = "${var.source_image != "" ? var.source_image : "debian-9-stretch-v20190326"}"
}

data "google_compute_image" "image_family" {
  project = "${var.source_image_family != "" ? var.source_image_project : "debian-cloud"}"
  family  = "${var.source_image_family != "" ? var.source_image_family : "debian-9"}"
}

data "template_file" "startup_script_config" {
  template = "${file("${path.module}/scripts/startup.tpl")}"
  vars = {
    ENVIRONMENT = "${var.environment}${random_id.service_account.hex}"
    PROTECTION_LEVEL = "${var.kms_protection_level}"
    REGION = "${var.region}"
    IMPORT_JOB = "${google_kms_key_ring_import_job.import_job.name}"
    HOME = "${local.home}"
    BASE_DIR = "${local.BASE_DIR}"
    OPENSSL_V110 = "${local.OPENSSL_V110}"
    WRAP_PUB_KEY = "${local.WRAP_PUB_KEY}"
    TARGET_KEY = "${local.TARGET_KEY}"
    RSA_AES_WRAPPED_KEY = "${local.RSA_AES_WRAPPED_KEY}"
    TEMP_AES_KEY = "${local.TEMP_AES_KEY}"
    TEMP_AES_KEY_WRAPPED = "${local.TEMP_AES_KEY_WRAPPED}"
    TARGET_KEY_WRAPPED = "${local.TARGET_KEY_WRAPPED}"
  }
}

#########
# Locals
#########

locals {
  boot_disk = [{
    source_image = "${var.source_image != "" ? data.google_compute_image.image.self_link : data.google_compute_image.image_family.self_link}"
    disk_size_gb = "${var.disk_size_gb}"
    disk_type    = "${var.disk_type}"
    auto_delete  = "${var.auto_delete}"
    boot         = "true"
  }]

  home = "/root"
  BASE_DIR = "/root/wrap_tmp"
  OPENSSL_V110 = "/opt/local/bin/openssl.sh"
  algorithm = "google-symmetric-encryption"
  WRAP_PUB_KEY = "${local.home}/public_key_from_hsm.pem"
  TARGET_KEY = "${local.home}/customer_key_to_be_imported.bin"
  RSA_AES_WRAPPED_KEY = "${local.home}/wrapped_key_to_be_imported.bin"
  TEMP_AES_KEY = "${local.BASE_DIR}/temp_aes_key.bin"
  TEMP_AES_KEY_WRAPPED = "${local.BASE_DIR}/temp_aes_key_wrapped.bin"
  TARGET_KEY_WRAPPED = "${local.BASE_DIR}/target_key_wrapped.bin"
}

####################
# Enable Project Services
####################

resource "google_project_service" "project_services" {
  count                      = var.enable_apis ? length(var.activate_apis) : 0
  project                    = "${var.project_id}"
  service                    = element(var.activate_apis, count.index)
  disable_on_destroy         = var.disable_services_on_destroy
  disable_dependent_services = var.disable_dependent_services
}


####################
# Service account for compute instance
####################

resource "random_id" "service_account" {
  byte_length = 4
}

resource "google_service_account" "service_account" {
  account_id   = "${var.environment}${random_id.service_account.hex}"
  display_name = "${var.environment}${random_id.service_account.hex}"
  project      = "${var.project_id}"
  depends_on   = ["google_project_service.project_services"]
}

resource "google_project_iam_member" "Compute_admin" {
  project    = "${var.project_id}"
  role       = "roles/compute.admin"
  member     = "serviceAccount:${google_service_account.service_account.email}"
  depends_on = ["google_project_service.project_services"]
}

resource "google_project_iam_member" "Storage_viewer" {
  project    = "${var.project_id}"
  role       = "roles/storage.objectViewer"
  member     = "serviceAccount:${google_service_account.service_account.email}"
  depends_on = ["google_project_service.project_services"]
}

resource "google_kms_key_ring_iam_member" "Crypto_import" {
  key_ring_id = "${google_kms_key_ring.key_ring.self_link}"
  role          = "roles/cloudkms.admin"
  member        = "serviceAccount:${google_service_account.service_account.email}"
  depends_on    = ["google_project_service.project_services"]
}

####################
# Build OS template
####################
resource "google_compute_instance_template" "os_template" {
  project                 = "${var.project_id}"
  name_prefix             = "${var.environment}-"
  machine_type            = "${var.machine_type}"
  labels                  = "${var.labels}"
  metadata                = "${var.metadata}"
  tags                    = ["${var.environment}"]
  can_ip_forward          = "${var.can_ip_forward}"
  metadata_startup_script = "${data.template_file.startup_script_config.rendered}"

  service_account {
    email  = "${google_service_account.service_account.email}"
    scopes = ["cloud-platform"]
  }

  disk {
    source_image = "${var.source_image != "" ? data.google_compute_image.image.self_link : data.google_compute_image.image_family.self_link}"
    disk_size_gb = "${var.disk_size_gb}"
    disk_type    = "${var.disk_type}"
    auto_delete  = "${var.auto_delete}"
    boot         = "true"
  }

  network_interface {
    network            = "${var.network}"
    subnetwork         = "${var.subnetwork}"
    subnetwork_project = "${var.subnetwork_project}"
  }

  lifecycle {
    create_before_destroy = "false"
  }
  depends_on = ["google_project_service.project_services"]
}

####################
# Deploy an instance 
####################
resource "google_compute_instance_from_template" "deploy_os_template" {
  name                     = "${var.environment}${random_id.service_account.hex}"
  zone                     = "${var.zone}"
  project                  = "${var.project_id}"
  source_instance_template = "${google_compute_instance_template.os_template.self_link}"
  depends_on               = ["google_project_service.project_services"]
}

####################
# Create KMS resources
####################

resource "google_kms_key_ring" "key_ring" {
  name       = "${var.environment}${random_id.service_account.hex}"
  location   = "${var.region}"
  project    = "${var.project_id}"
  depends_on = ["google_project_service.project_services"]
}

resource "google_kms_crypto_key" "key" {
  name            = "${var.environment}${random_id.service_account.hex}"
  key_ring        = google_kms_key_ring.key_ring.self_link

  lifecycle {
    prevent_destroy = false
  }

  version_template {
    algorithm        = var.key_algorithm
    protection_level = var.kms_protection_level
  }

}

resource "google_kms_key_ring_import_job" "import_job" {
  key_ring = google_kms_key_ring.key_ring.id
  import_job_id = "${var.environment}${random_id.service_account.hex}"
  import_method = "RSA_OAEP_3072_SHA1_AES_256"
  protection_level = var.kms_protection_level
}
