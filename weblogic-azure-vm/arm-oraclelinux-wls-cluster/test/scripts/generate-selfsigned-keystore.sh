#!/bin/bash

read wlsDemoIdentityKeyStorePassPhrase wlsDemoIdentityPassPhrase wlsDemoTrustPassPhrase

export wlsIdentityKeyStoreFileName="identity.p12"
export wlsTrustKeyStoreFileName="trust.p12"
export wlsTrustKeyStoreJKSFileName="trust.jks"
export wlsIdentityRootCertFileName="root.cert"
export wlsDemoIndetityKeyAlias="demoidentity"

function generate_selfsigned_certificates() {
    # Note: JDK 8 keytool will create jks by default
    # JDK 11 keytool will create PKCS12 by default
    # This file uses JDK 21.
    echo "Generate identity key store."
    ${JAVA_HOME}/bin/keytool -genkey \
        -alias ${wlsDemoIndetityKeyAlias} \
        -keyalg RSA -keysize 2048 \
        -sigalg SHA256withRSA -validity 365 \
        -keystore $wlsIdentityKeyStoreFileName \
        -keypass ${wlsDemoIdentityPassPhrase} \
        -storepass ${wlsDemoIdentityKeyStorePassPhrase} \
        -dname "CN=test, OU=test, O=test, L=test, ST=test, C=test"

    # update the input variables with Demo values
    local wlsIdentityPsw=${wlsDemoIdentityKeyStorePassPhrase}
    local wlsIdentityType="PKCS12"
    local wlsIdentityAlias=${wlsDemoIndetityKeyAlias}
    local wlsIdentityKeyPsw=${wlsDemoIdentityPassPhrase}
    echo "Exporting root cert from identity key store"
    ${JAVA_HOME}/bin/keytool -export \
        -alias ${wlsDemoIndetityKeyAlias} \
        -noprompt \
        -file ${wlsIdentityRootCertFileName} \
        -keystore $wlsIdentityKeyStoreFileName \
        -storepass ${wlsDemoIdentityKeyStorePassPhrase}
    echo "Exporting root cert from identity key store"
    ${JAVA_HOME}/bin/keytool -import \
        -alias ${wlsDemoIndetityKeyAlias} \
        -noprompt \
        -file ${wlsIdentityRootCertFileName} \
        -keystore ${wlsTrustKeyStoreFileName} \
        -storepass ${wlsDemoTrustPassPhrase}
    echo "Generate trust key store."
}

echo "Starting to generate selfsigned certificates"
generate_selfsigned_certificates