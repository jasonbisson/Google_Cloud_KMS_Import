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
export kms_protection_level=hsm
export location=$(gcloud config list --format 'value(compute.region)')
export import_method='rsa-oaep-3072-sha1-aes-256'
export project_id=$(gcloud config list --format 'value(core.project)')
export random=$(echo $RANDOM)
export WRAP_PUB_KEY="/tmp/public_key_from_hsm.pem"

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
    
}

function create_import () {
    gcloud beta kms import-jobs create $environment-$random \
    --location  $location \
    --keyring $environment \
    --import-method $import_method \
    --protection-level ${kms_protection_level}
}


function save_public_key {
    #import_job=$(gcloud beta kms import-jobs list --location $location --keyring $environment \
    #--format json |jq -r .[].name |awk -F\/ '{print $8}')
    import_job=$(gcloud beta kms import-jobs list --location=$location --keyring=$environment --format="value(name)" | awk -F\/ '{print $8}')
    #gcloud beta kms import-jobs describe $import_job --location $location \
    #--keyring $environment --format json |jq -r .publicKey.pem > $WRAP_PUB_KEY
    gcloud kms import-jobs describe $import_job --location=$location --keyring=$environment --format="value(publicKey.pem)" > $WRAP_PUB_KEY
}

check_variables
create_import
save_puublic_key