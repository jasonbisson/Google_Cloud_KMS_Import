This repository will go through the fun adventure of importing a symmetric key into KMS with software or hardware protection with Cloud HSM. The terraform deployment will deploy a linux instance and Cloud NAT instance with a startup script that installs all the required packages required to wrap the key before import and attempts to import a symmetric key. In addition, there are scripts run through the process manually.

### Requirements

## Gcloud SDK
Download the latest gcloud SDK
https://cloud.google.com/sdk/docs/

### Terraform plugins
- [Terraform](https://www.terraform.io/downloads.html) 0.12.x
- [terraform-provider-google](https://github.com/hashicorp/terraform-provider-google) plugin v2.7.0

### APIs
The following APIs must be enabled in the project:
- Identity and Access Management API: `iam.googleapis.com`
- Compute `compute.googleapis.com`
- Cloud Functions `cloudfunctions.googleapis.com`

### Service account
We need two Terraform service accounts for this module:
* **Terraform service account** (that will create the Linux Instance, Cloud Nat, and KMS keyring)
* **GCE service account** (that will be used on the Linux Instance to install the required packages, wrap the key, and import the key in KMS or HSM)

The **Terraform service account** used to run this module must have the following IAM Roles:
- `Project IAM Admin` on the project to grant permissions to the VM service account.
- `Compute Instance Admin` on the project to create the GCE.
- `Project Cloud KMS` on the project to create KMS keyring.
- 

## Install

### Terraform
Be sure you have the correct Terraform version (0.12.x), you can choose the binary here:
- https://releases.hashicorp.com/terraform/

Then perform the following commands:
-  Create a Google Storage bucket to store Terraform state 
-  `gsutil mb gs://<your state bucket>`
-  Copy terraform.tfvars.template to terraform.tfvars 
-  `cp terraform.tfvars.template  terraform.tfvars`
-  Update required variables in terraform.tfvars for Splunk Software, GCS Bucket, and DNS configuration 
- `terraform init` to get the plugins
-  Enter Google Storage bucket that will store the Terraform state
- `terraform plan` to see the infrastructure plan
- `terraform apply` to apply the infrastructure build
- `terraform destroy` to destroy the built infrastructure

### Manual Usage 

### Build custom Openssl package for wrapping
$ build_custom_openssl.sh

### Create KMS Import Job
$ create_import_job.sh

### Creates a symmetric key in home directory:
$ create_symmetric_key.sh
$ ls -l customer_key_to_be_imported.bin

### Wrap Customer symmetric key with KMS import job public Key
$ wrap_customer_key.sh

### Import the wrapped symmetric key 
$ import_wrapped_key.sh

## File structure
The project has the following folders and files:

- /modules: modules folder
- /scripts: Script to manually run the import process
- /main.tf: main file for this module, contains all the resources to create
- /variables.tf: all the variables for the module
- /readme.MD: this file