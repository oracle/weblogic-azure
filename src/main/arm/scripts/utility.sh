# Copyright (c) 2019, 2020, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

function install_jdk() {
    # Install Microsoft OpenJDK
    apk --no-cache add openjdk11 --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community

    echo "java version"
    java -version
    if [ $? -eq 1 ]; then
        exit 1
    fi
    # JAVA_HOME=/usr/lib/jvm/java-11-openjdk
}

function install_kubectl() {
    # Install kubectl
    az aks install-cli
    echo "validate kubectl"
    kubectl --help
    if [ $? -eq 1 ]; then
        echo "Failed to install kubectl."
        exit 1
    fi
}