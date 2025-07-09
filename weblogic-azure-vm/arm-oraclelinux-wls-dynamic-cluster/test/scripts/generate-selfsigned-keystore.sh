#!/bin/bash

# After running this script, you will have the following files in the current directory:
# identity.jks - Identity keystore
# trust.jks - Trust keystore
# root.cert - Root certificate

read wlsDemoIdentityKeyStorePassPhrase wlsDemoIdentityPassPhrase wlsDemoTrustPassPhrase

export wlsIdentityKeyStoreFileName="identity.jks"
export wlsTrustKeyStoreFileName="trust.jks"
export wlsIdentityRootCertFileName="root.cert"
export wlsDemoIndetityKeyAlias="demoidentity"

function generate_selfsigned_certificates() {
    # Note: JDK 8 keytool will create jks by default
    # JDK 11 keytool will create PKCS12 by default
    # This file uses JDK 11 and generates JKS.
    echo "Generate identity key store."
    ${JAVA_HOME}/bin/keytool -genkey \
        -alias ${wlsDemoIndetityKeyAlias} \
        -keyalg RSA -keysize 2048 \
        -sigalg SHA256withRSA -validity 365 \
        -keystore $wlsIdentityKeyStoreFileName \
        -keypass ${wlsDemoIdentityPassPhrase} \
        -storepass ${wlsDemoIdentityKeyStorePassPhrase} \
        -storetype JKS \
        -dname "CN=*.cloudapp.azure.com, OU=test, O=test, L=test, ST=test, C=test"

    # update the input variables with Demo values
    echo "Exporting root cert from identity key store"
    ${JAVA_HOME}/bin/keytool -export \
        -alias ${wlsDemoIndetityKeyAlias} \
        -noprompt \
        -file ${wlsIdentityRootCertFileName} \
        -keystore $wlsIdentityKeyStoreFileName \
        -storepass ${wlsDemoIdentityKeyStorePassPhrase}

    echo "Generate trust key store."
    ${JAVA_HOME}/bin/keytool -import \
        -alias ${wlsDemoIndetityKeyAlias} \
        -noprompt \
        -file ${wlsIdentityRootCertFileName} \
        -keystore ${wlsTrustKeyStoreFileName} \
        -storepass ${wlsDemoTrustPassPhrase} \
        -storetype JKS    
}
# check if the selfsigned certificates alias already exist, if it does, skip the generation
if ${JAVA_HOME}/bin/keytool -list -keystore $wlsIdentityKeyStoreFileName -storepass ${wlsDemoIdentityKeyStorePassPhrase} | grep -q "${wlsDemoIndetityKeyAlias}"; then
    echo "Selfsigned certificates alias already exist in the identity keystore, skipping generation"
    exit 0
else
    echo "Selfsigned certificates alias does not exist in the identity keystore, generating selfsigned certificates"

echo "Starting to generate selfsigned certificates"
generate_selfsigned_certificates
