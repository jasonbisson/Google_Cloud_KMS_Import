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

OPENSSL_V110="/opt/local/bin/openssl.sh"
WRAP_PUB_KEY="${HOME}/public_key_from_hsm.pem"
TARGET_KEY="$HOME/customer_key_to_be_imported.bin"
RSA_AES_WRAPPED_KEY="$HOME/wrapped_key_to_be_imported.bin"

BASE_DIR="${HOME}/wrap_tmp"
mkdir -m 700 -p ${BASE_DIR}
TEMP_AES_KEY="${BASE_DIR}/temp_aes_key.bin"
TEMP_AES_KEY_WRAPPED="${BASE_DIR}/temp_aes_key_wrapped.bin"
TARGET_KEY_WRAPPED="${BASE_DIR}/target_key_wrapped.bin"


function create_temp_aes_key () {
    "${OPENSSL_V110}" rand -out "${TEMP_AES_KEY}" 32
}

function wrap_temp_aes_key () {
    "${OPENSSL_V110}" rsautl -encrypt \
    -pubin -inkey "${WRAP_PUB_KEY}" \
    -in "${TEMP_AES_KEY}" \
    -out "${TEMP_AES_KEY_WRAPPED}" \
    -oaep
}

function wrap_target_key () {
    "${OPENSSL_V110}" enc -id-aes256-wrap-pad \
    -K $( hexdump -v -e '/1 "%02x"' < "${TEMP_AES_KEY}" ) \
    -iv A65959A6 \
    -in "${TARGET_KEY}" \
    -out "${TARGET_KEY_WRAPPED}"
}

function concat_wrapped_keys () {
    cat "${TEMP_AES_KEY_WRAPPED}" "${TARGET_KEY_WRAPPED}" > "${RSA_AES_WRAPPED_KEY}"
}

function cleanup_keys () {
    rm ${BASE_DIR}/*
}

create_temp_aes_key
wrap_temp_aes_key
wrap_target_key
concat_wrapped_keys
cleanup_keys