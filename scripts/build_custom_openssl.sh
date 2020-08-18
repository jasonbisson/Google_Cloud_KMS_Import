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

function download_openssl () {
    mkdir $HOME/build
    mkdir -p $HOME/local/ssl
    cd $HOME/build
    curl -O https://www.openssl.org/source/openssl-1.1.0j.tar.gz
    tar -zxf openssl-1.1.0j.tar.gz
    sudo apt-get install gcc make
}

function patch_openssl () {
cat <<-EOF | patch -d $HOME/build/ -p0
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
    cd $HOME/build/openssl-1.1.0j/
    ./config --prefix=$HOME/local --openssldir=$HOME/local/ssl
    make -j$(grep -c ^processor /proc/cpuinfo)
    make test
    make install
}

function test_custom_openssl () {
    cd $HOME
    test -x local/bin/openssl || echo FAIL
}

function openssl_script () {
    cd $HOME/local/bin/
cat > ./openssl.sh <<-EOF
#!/bin/bash
env LD_LIBRARY_PATH=$HOME/local/lib/ $HOME/local/bin/openssl "\$@"
EOF
    chmod 755 ./openssl.sh
}

download_openssl
patch_openssl
build_custom_openssl