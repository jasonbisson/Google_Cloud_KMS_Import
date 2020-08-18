#!/bin/bash
#set -x
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

if [ $# -ne 1 ]; then
    echo $0: usage: Requires argument of i.e. senddata
    exit 1
fi

export environment=$1
export location=$(gcloud config list --format 'value(compute.region)')
export import_method='rsa-oaep-3072-sha1-aes-256'
export project_id=$(gcloud config list --format 'value(core.project)')
export key_to_import="$HOME/wrapped_key_to_be_imported.bin"
export import_job=$(gcloud beta kms import-jobs list --location $location --keyring $environment \
--format json |jq -r .[].name |awk -F\/ '{print $8}')
export algorithm='google-symmetric-encryption'


function check_variables () {
    if [  -z "$project_id" ]; then
        printf "ERROR: GCP PROJECT_ID is not set.\n\n"
        printf "To view the current PROJECT_ID config: gcloud config list project \n\n"
        printf "To view available projects: gcloud projects list \n\n"
        printf "To update project config: gcloud config set project PROJECT_ID \n\n"
        exit
    fi
    
    if [  -z "$location" ]; then
        printf "ERROR: Region is not set.\n\n"
        printf "Region is required import into the correct keyring"
        exit
    fi
    
    if [  -z "$import_job" ]; then
        printf "ERROR: Region is not set.\n\n"
        printf "Region is required import into the correct keyring"
        exit
    fi
    
}

function install_crypto_package () {
    sudo apt-get install python-cryptography
    sudo apt install python3-pip
    export CLOUDSDK_PYTHON_SITEPACKAGES=1
}

function create_empty_key () {
    gcloud kms keys create $environment \
  --location $location \
  --keyring $environment \
  --protection-level=hsm
  --purpose encryption \
  --skip-initial-version-creation
}

function create_import () {
    gcloud beta kms keys versions import \
    --import-job $import_job \
    --location $location \
    --keyring $environment \
    --key $environment \
    --algorithm $algorithm \
    --rsa-aes-wrapped-key-file $key_to_import
}

function check_import () {
    gcloud kms keys versions describe VERSION \
    --location $location \
    --keyring $environment \
    --key $environment
}




check_variables
create_empty_key
create_import