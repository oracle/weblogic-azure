#!/bin/bash
# Script to check available API versions in the Azure subscription used by CI/CD

echo "=== Azure Subscription Info ==="
az account show --query '{subscriptionId:id, tenantId:tenantId, name:name, state:state}' -o json

echo -e "\n=== Resource Provider Registration Status ==="
echo "Checking Microsoft.Compute..."
az provider show --namespace Microsoft.Compute --query "{namespace:namespace, registrationState:registrationState}" -o json

echo -e "\nChecking Microsoft.Network..."
az provider show --namespace Microsoft.Network --query "{namespace:namespace, registrationState:registrationState}" -o json

echo -e "\nChecking Microsoft.Storage..."
az provider show --namespace Microsoft.Storage --query "{namespace:namespace, registrationState:registrationState}" -o json

echo -e "\nChecking Microsoft.Resources..."
az provider show --namespace Microsoft.Resources --query "{namespace:namespace, registrationState:registrationState}" -o json

echo -e "\n=== Available API Versions (2024 only) ==="
echo "Microsoft.Compute/virtualMachines:"
az provider show --namespace Microsoft.Compute --query "resourceTypes[?resourceType=='virtualMachines'].apiVersions" -o json | jq -r '.[][] | select(test("preview"; "i") | not) | select(test("^2024"))'

echo -e "\nMicrosoft.Compute/virtualMachines/extensions:"
az provider show --namespace Microsoft.Compute --query "resourceTypes[?resourceType=='virtualMachines/extensions'].apiVersions" -o json | jq -r '.[][] | select(test("preview"; "i") | not) | select(test("^2024"))'

echo -e "\nMicrosoft.Network/networkInterfaces:"
az provider show --namespace Microsoft.Network --query "resourceTypes[?resourceType=='networkInterfaces'].apiVersions" -o json | jq -r '.[][] | select(test("preview"; "i") | not) | select(test("^2024"))'

echo -e "\nMicrosoft.Network/publicIPAddresses:"
az provider show --namespace Microsoft.Network --query "resourceTypes[?resourceType=='publicIPAddresses'].apiVersions" -o json | jq -r '.[][] | select(test("preview"; "i") | not) | select(test("^2024"))'

echo -e "\nMicrosoft.Network/applicationGateways:"
az provider show --namespace Microsoft.Network --query "resourceTypes[?resourceType=='applicationGateways'].apiVersions" -o json | jq -r '.[][] | select(test("preview"; "i") | not) | select(test("^2024"))'

echo -e "\nMicrosoft.Network/virtualNetworks:"
az provider show --namespace Microsoft.Network --query "resourceTypes[?resourceType=='virtualNetworks'].apiVersions" -o json | jq -r '.[][] | select(test("preview"; "i") | not) | select(test("^2024"))'

echo -e "\nMicrosoft.Storage/storageAccounts:"
az provider show --namespace Microsoft.Storage --query "resourceTypes[?resourceType=='storageAccounts'].apiVersions" -o json | jq -r '.[][] | select(test("preview"; "i") | not) | select(test("^2024"))'

echo -e "\nMicrosoft.Resources/deployments:"
az provider show --namespace Microsoft.Resources --query "resourceTypes[?resourceType=='deployments'].apiVersions" -o json | jq -r '.[][] | select(test("preview"; "i") | not) | select(test("^2024"))'
