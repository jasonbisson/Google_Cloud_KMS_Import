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

export environment=${ENVIRONMENT}
export location=${REGION}
export kms_protection_level=${PROTECTION_LEVEL}
export import_job =${IMPORT_JOB}
export import_method='rsa-oaep-3072-sha1-aes-256'
export random=$(echo $RANDOM)
export algorithm='google-symmetric-encryption'
export OPENSSL_V110=${OPENSSL_V110}
export WRAP_PUB_KEY=${WRAP_PUB_KEY}
export TARGET_KEY=${TARGET_KEY}
export RSA_AES_WRAPPED_KEY=${RSA_AES_WRAPPED_KEY}
export HOME=${HOME}
export BASE_DIR=${BASE_DIR}
mkdir -m 700 -p ${BASE_DIR}
export TEMP_AES_KEY=${TEMP_AES_KEY}
export TEMP_AES_KEY_WRAPPED=${TEMP_AES_KEY_WRAPPED}
export TARGET_KEY_WRAPPED=${TARGET_KEY_WRAPPED}

function check_previous_install () {
    if [ -x "$(command -v /opt/local/bin/openssl.sh )" ]; then
        echo 'Info: custom openssl is installed.' >&2
        exit 1
    fi
}

function download_openssl () {
    sudo mkdir /opt/build
    sudo mkdir -p /opt/local/ssl
    cd /opt/build
    sudo curl -O https://www.openssl.org/source/openssl-1.1.0j.tar.gz
    sudo tar -zxf openssl-1.1.0j.tar.gz
    sudo apt-get install -y gcc make patch apt-file git jq
}

function patch_openssl () {
sudo cat <<-EOF | patch -d /opt/build/ -p0
diff -ur orig/openssl-1.1.0j/apps/enc.c openssl-1.1.0j/apps/enc.c
--- orig/openssl-1.1.0j/apps/enc.c      2017-11-02 10:29:02.000000000 -0400
+++ openssl-1.1.0j/apps/enc.c   2017-11-18 14:00:31.106304557 -0500
@@ -478,6 +478,7 @@
          */

         BIO_get_cipher_ctx(benc, &ctx);
+        EVP_CIPHER_CTX_set_flags(ctx, EVP_CIPHER_CTX_FLAG_WRAP_ALLOW);

         if (!EVP_CipherInit_ex(ctx, cipher, NULL, NULL, NULL, enc)) {
             BIO_printf(bio_err, "Error setting cipher %s\n",
EOF
}

function build_custom_openssl () {
    cd /opt/build/openssl-1.1.0j/
    sudo ./config --prefix=/opt/local --openssldir=/opt/local/ssl
    sudo make -j$(grep -c ^processor /proc/cpuinfo)
    sudo make test
    sudo make install
}

function test_custom_openssl () {
    cd /opt
    test -x local/bin/openssl || echo FAIL
}

function openssl_script () {
    cd /opt/local/bin/
sudo cat > ./openssl.sh <<-EOF
#!/bin/bash
env LD_LIBRARY_PATH=/opt/local/lib/ /opt/local/bin/openssl "\$@"
EOF
    sudo chmod 755 ./openssl.sh
}

function download_public_key {
    export import_job=$(gcloud beta kms import-jobs list --location=$location --keyring=$environment --format="value(name)" | awk -F\/ '{print $8}')
    gcloud kms import-jobs describe $import_job --location=$location --keyring=$environment --format="value(publicKey.pem)" > $WRAP_PUB_KEY
}

function create_customer_key {
dd if=/dev/urandom bs=32 count=1 of=${TARGET_KEY}
}

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

function import_wrapped_key () {
    gcloud beta kms keys versions import \
    --import-job $import_job \
    --location $location \
    --keyring $environment \
    --key $environment \
    --algorithm $algorithm \
    --rsa-aes-wrapped-key-file $RSA_AES_WRAPPED_KEY
}

#Build Openssl
download_openssl
patch_openssl
build_custom_openssl
test_custom_openssl
openssl_script

#Wrap customer key
download_public_key
create_customer_key
create_temp_aes_key
wrap_temp_aes_key
wrap_target_key
concat_wrapped_keys
cleanup_keys

#Import Key
import_wrapped_key 