# Copyright (c) 2021, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

echo "Script  ${0} starts"

#Function to output message to StdErr
function echo_stderr() {
    echo "$@" >&2
}

# read <azureACRPassword> and <ocrSSOPSW> from stdin
function read_sensitive_parameters_from_stdin() {
    read azureACRPassword ocrSSOPSW
}

#Function to display usage message
function usage() {
    echo "<azureACRPassword> <ocrSSOPSW> | ./buildWLSDockerImage.sh <wlsImagePath> <azureACRServer> <azureACRUserName> <imageTag> <appPackageUrls> <ocrSSOUser> <wlsClusterSize> <enableSSL> <enableAdminT3Tunneling> <enableClusterT3Tunneling> <dbDriversUrls>"
    if [ $1 -eq 1 ]; then
        exit 1
    fi
}

# Validate teminal status with $?, exit if errors happen.
function validate_status() {
    if [ $? == 1 ]; then
        echo "$@" >&2
        echo "Errors happen, exit 1."
        exit 1
    fi
}

function validate_inputs() {
    if [ -z "$useOracleImage" ]; then
        echo_stderr "userProvidedImagePath is required. "
        usage 1
    fi

    if [ -z "$wlsImagePath" ]; then
        echo_stderr "wlsImagePath is required. "
        usage 1
    fi

    if [ -z "$azureACRServer" ]; then
        echo_stderr "azureACRServer is required. "
        usage 1
    fi

    if [ -z "$azureACRUserName" ]; then
        echo_stderr "azureACRUserName is required. "
        usage 1
    fi

    if [ -z "$azureACRPassword" ]; then
        echo_stderr "azureACRPassword is required. "
        usage 1
    fi

    if [ -z "$imageTag" ]; then
        echo_stderr "imageTag is required. "
        usage 1
    fi

    if [ -z "$appPackageUrls" ]; then
        echo_stderr "appPackageUrls is required. "
        usage 1
    fi

    if [[ "${useOracleImage,,}" == "${constTrue}" ]] && [ -z "$ocrSSOUser" ]; then
        echo_stderr "ocrSSOUser is required. "
        usage 1
    fi

    if [[ "${useOracleImage,,}" == "${constTrue}" ]] && [ -z "$ocrSSOPSW" ]; then
        echo_stderr "ocrSSOPSW is required. "
        usage 1
    fi

    if [ -z "$wlsClusterSize" ]; then
        echo_stderr "wlsClusterSize is required. "
        usage 1
    fi

    if [ -z "$enableSSL" ]; then
        echo_stderr "enableSSL is required. "
        usage 1
    fi

    if [ -z "$enableAdminT3Tunneling" ]; then
        echo_stderr "enableAdminT3Tunneling is required. "
        usage 1
    fi

    if [ -z "$enableClusterT3Tunneling" ]; then
        echo_stderr "enableClusterT3Tunneling is required. "
        usage 1
    fi

    if [ -z "${dbDriversUrls}" ]; then
        echo_stderr "dbDriversUrls is required. "
        usage 1
    fi
}

function initialize() {
    if [ -d "model-images" ]; then
        rm model-images -f -r
    fi

    mkdir model-images
    cd model-images

    # Create Model directory
    mkdir wlsdeploy
    mkdir wlsdeploy/config
    mkdir wlsdeploy/applications
    mkdir wlsdeploy/domainLibraries
}

# Install docker, zip, unzip and java
# Download WebLogic Tools
function install_utilities() {
    # Install docker
    sudo apt-get -q update
    sudo apt-get -y -q install apt-transport-https
    curl -m ${curlMaxTime} -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo \
        "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    sudo apt-get -q update
    sudo apt-get -y -q install docker-ce docker-ce-cli containerd.io

    echo "docker version"
    sudo docker --version
    validate_status "Check status of docker."
    sudo systemctl start docker

    # Install Microsoft OpenJDK
    wget https://packages.microsoft.com/config/ubuntu/18.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
    sudo dpkg -i packages-microsoft-prod.deb
    sudo apt -q update
    sudo apt -y -q install msopenjdk-11

    echo "java version"
    java -version
    validate_status "Check status of Zulu JDK 8."

    export JAVA_HOME=/usr/lib/jvm/msopenjdk-11-amd64
    if [ ! -d "${JAVA_HOME}" ]; then
        echo "Java home ${JAVA_HOME} does not exist"
        exit 1
    fi

    sudo apt -y -q install zip
    zip --help
    validate_status "Check status of zip."

    sudo apt -y -q install unzip
    echo "unzip version"
    unzip --help
    validate_status "Check status of unzip."

    # Download weblogic tools
    curl -m ${curlMaxTime} -fL ${wdtDownloadURL} -o weblogic-deploy.zip
    validate_status "Check status of weblogic-deploy.zip."

    curl -m ${curlMaxTime} -fL ${witDownloadURL} -o imagetool.zip
    validate_status "Check status of imagetool.zip."

    curl -m ${curlMaxTime} -fL ${wlsPostgresqlDriverUrl} -o ${scriptDir}/model-images/wlsdeploy/domainLibraries/${constPostgreDriverName}
    validate_status "Install postgresql driver."

    curl -m ${curlMaxTime} -fL ${wlsMSSQLDriverUrl} -o ${scriptDir}/model-images/wlsdeploy/domainLibraries/${constMSSQLDriverName}
    validate_status "Install mssql driver."
}

function install_db_drivers() {
    if [ "${dbDriversUrls}" == "[]" ] || [ -z "${dbDriversUrls}" ]; then
        return
    fi

    local dbDriversUrls=$(echo "${dbDriversUrls:1:${#dbDriversUrls}-2}")
    local dbDriversUrlsArray=$(echo $dbDriversUrls | tr "," "\n")

    for item in $dbDriversUrlsArray; do
        echo ${item}
        # e.g. https://wlsaksapp.blob.core.windows.net/japps/mariadb-java-client-2.7.4.jar?sp=r&se=2021-04-29T15:12:38Z&sv=2020-02-10&sr=b&sig=7grL4qP%2BcJ%2BLfDJgHXiDeQ2ZvlWosRLRQ1ciLk0Kl7M%3D
        local urlWithoutQueryString="${item%\?*}"
        echo $urlWithoutQueryString
        local fileName="${urlWithoutQueryString##*/}"
        echo $fileName

        curl -m ${curlMaxTime} -fL "$item" -o ${scriptDir}/model-images/wlsdeploy/domainLibraries/${fileName}
        if [ $? -ne 0 ];then
          echo "Failed to download $item"
          exit 1
        fi

        dbDriverPaths="${dbDriverPaths},'wlsdeploy/domainLibraries/${fileName}'"
    done
}

# Login in OCR
# Pull weblogic image
function get_wls_image_from_ocr() {
    sudo docker logout
    sudo docker login ${ocrLoginServer} -u ${ocrSSOUser} -p ${ocrSSOPSW}
    echo "Start to pull oracle image ${wlsImagePath}  ${ocrLoginServer} ${ocrSSOUser} ${ocrSSOPSW}"
    sudo docker pull -q ${wlsImagePath}
    validate_status "Finish pulling image from OCR."
}

# Get user provided image
function get_user_provided_wls_image_from_acr() {
    sudo docker logout
    sudo docker login ${azureACRServer} -u ${azureACRUserName} -p ${azureACRPassword}
    echo "Start to pull user provided image ${wlsImagePath} ${azureACRServer} ${azureACRUserName} ${azureACRPassword}"
    sudo docker pull -q ${wlsImagePath}
    validate_status "Finish pulling image from OCR."
}

# Generate model configurations
function prepare_wls_models() {
    # Create configuration in model.properties
    echo "Create configuration in properties file"
    cat <<EOF >>${scriptDir}/model.properties
CLUSTER_SIZE=${wlsClusterSize}
EOF

    echo "Starting generation of image model file..."
    modelFilePath="$scriptDir/model.yaml"

    chmod ugo+x $scriptDir/genImageModel.sh
    bash $scriptDir/genImageModel.sh \
        ${modelFilePath} \
        ${appPackageUrls} \
        ${enableSSL} \
        ${enableAdminT3Tunneling} \
        ${enableClusterT3Tunneling}
    validate_status "Generate image model file."
}

# Build weblogic image
# Push the image to ACR
function build_wls_image() {
    # Add WDT
    unzip imagetool.zip
    ./imagetool/bin/imagetool.sh cache addInstaller \
        --type wdt \
        --version latest \
        --path ${scriptDir}/model-images/weblogic-deploy.zip

    # Zip wls model and applications
    zip -r ${scriptDir}/model-images/archive.zip wlsdeploy

    # inspect user/group of the base image
    local imageInfo=$(./imagetool/bin/imagetool.sh inspect --image ${wlsImagePath})
    # {
    #     "os" : {
    #         "id" : "ol",
    #         "name" : "Oracle Linux Server",
    #         "version" : "7.9"
    #     },
    #     "javaHome" : "/u01/jdk",
    #     "javaVersion" : "1.8.0_271",
    #     "oracleHome" : "/u01/oracle",
    #     "oracleHomeGroup" : "oracle",
    #     "oracleHomeUser" : "oracle",
    #     "oracleInstalledProducts" : "WLS,COH,TOPLINK",
    #     "packageManager" : "YUM",
    #     "wlsVersion" : "12.2.1.4.0"
    # }
    echo ${imageInfo}
    local user=${imageInfo#*oracleHomeUser}
    local user=$(echo ${user%%\,*} | tr -d "\"\:\ ")
    local group=${imageInfo#*oracleHomeGroup}
    local group=$(echo ${group%%\,*} | tr -d "\"\:\ ")
    echo "use ${user}:${group} to update the image"

    # Build image
    echo "Start building WLS image."
    ./imagetool/bin/imagetool.sh update \
        --tag model-in-image:WLS-v1 \
        --fromImage ${wlsImagePath} \
        --wdtModel ${scriptDir}/model.yaml \
        --wdtVariables ${scriptDir}/model.properties \
        --wdtArchive ${scriptDir}/model-images/archive.zip \
        --wdtModelOnly \
        --wdtDomainType WLS \
        --chown ${user}:${group}

    validate_status "Check status of building WLS domain image."

    sudo docker tag model-in-image:WLS-v1 ${acrImagePath}

    # Push image to ACR
    sudo docker logout
    sudo docker login $azureACRServer -u ${azureACRUserName} -p ${azureACRPassword}
    echo "Start pushing image ${acrImagePath} to $azureACRServer."
    sudo docker push -q ${acrImagePath}
    validate_status "Check status of pushing WLS domain image."
    echo "Finish pushing image ${acrImagePath} to $azureACRServer."
}

# Initialize
export script="${BASH_SOURCE[0]}"
export scriptDir="$(cd "$(dirname "${script}")" && pwd)"

source ${scriptDir}/common.sh

export wlsImagePath=$1
export azureACRServer=$2
export azureACRUserName=$3
export imageTag=$4
export appPackageUrls=$5
export ocrSSOUser=$6
export wlsClusterSize=$7
export enableSSL=$8
export enableAdminT3Tunneling=$9
export enableClusterT3Tunneling=${10}
export useOracleImage=${11}
export dbDriversUrls=${12}

export acrImagePath="$azureACRServer/aks-wls-images:${imageTag}"
export dbDriverPaths=""

read_sensitive_parameters_from_stdin

validate_inputs

initialize

install_utilities

install_db_drivers

if [[ "${useOracleImage,,}" == "${constTrue}" ]]; then
    get_wls_image_from_ocr
else
    get_user_provided_wls_image_from_acr
fi

prepare_wls_models

build_wls_image
