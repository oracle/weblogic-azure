#!/bin/bash
# Local test script for API version validation
# This mimics what the CI/CD workflow does in the preflight job

set -e

echo "=== Testing Azure API Versions Locally ==="
echo ""

# Check if logged into Azure
if ! az account show &>/dev/null; then
    echo "ERROR: Not logged into Azure. Please run:"
    echo "  az login"
    echo "Or for service principal:"
    echo "  az login --service-principal -u <appId> -p <password> --tenant <tenant>"
    exit 1
fi

echo "Current Azure subscription:"
az account show --query '{name:name, subscriptionId:id}' -o table
echo ""

# Define variables
OFFER_NAME="arm-oraclelinux-wls-cluster"
OFFER_PATH="weblogic-azure-vm/arm-oraclelinux-wls-cluster"
LOCATION="centralus"
TEST_PREFIX="local-test-$$"

echo "=== Step 1: Building templates with Maven ==="
echo "This will substitute API versions from azure-common.properties"
mvn clean install -Ptemplate-validation-tests \
    --file ${OFFER_PATH}/pom.xml \
    -Dgit.repo.owner=oracle \
    -Dgit.tag=main \
    -q

echo ""
echo "=== Step 2: Checking substituted API versions in built templates ==="
TEMPLATE_FILE="${OFFER_PATH}/${OFFER_NAME}/target/arm/mainTemplate.json"

if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "ERROR: Template file not found at $TEMPLATE_FILE"
    exit 1
fi

echo "Checking API versions in generated template:"
grep -o '"apiVersion": "[^"]*"' "$TEMPLATE_FILE" | sort -u | head -20

echo ""
echo "=== Step 3: Creating test resource group ==="
TEST_RG="${TEST_PREFIX}-apitest"
az group create --name "$TEST_RG" --location "$LOCATION" --output none
echo "Created resource group: $TEST_RG"

echo ""
echo "=== Step 4: Running Azure template validation ==="
echo "This will show API version errors if any..."
echo ""

# Create a minimal parameters file for validation
cat > /tmp/test-params.json << 'EOF'
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "adminUsername": {"value": "testuser"},
    "adminPasswordOrKey": {"value": "Test123456!@#$%"},
    "acceptOTNLicenseAgreement": {"value": "Y"},
    "wlsDomainName": {"value": "testdomain"},
    "wlsUserName": {"value": "weblogic"},
    "wlsPassword": {"value": "Test123456!@#$%"},
    "numberOfInstances": {"value": 2},
    "vmSizeSelect": {"value": "Standard_D2s_v3"},
    "_artifactsLocation": {"value": "https://raw.githubusercontent.com/oracle/weblogic-azure/main/weblogic-azure-vm"},
    "_artifactsLocationSasToken": {"value": ""},
    "location": {"value": "centralus"}
  }
}
EOF

# Run validation
if az deployment group validate \
    -g "$TEST_RG" \
    -f "$TEMPLATE_FILE" \
    -p @/tmp/test-params.json \
    --no-prompt 2>&1 | tee /tmp/validation-output.txt; then
    echo ""
    echo "✅ SUCCESS: Template validation passed!"
    echo "All API versions are valid in this subscription."
else
    echo ""
    echo "❌ FAILED: Template validation errors detected"
    echo ""
    echo "API version errors found:"
    grep -i "apiVersion.*was not found" /tmp/validation-output.txt || echo "No API version errors (different error type)"
fi

echo ""
echo "=== Step 5: Cleanup ==="
az group delete --name "$TEST_RG" --yes --no-wait
echo "Resource group $TEST_RG deleted (background)"

# Cleanup temp files
rm -f /tmp/test-params.json /tmp/validation-output.txt

echo ""
echo "=== Test Complete ==="
