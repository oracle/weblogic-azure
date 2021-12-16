### Azure Service Principal (optional)

If you are going to enable the Azure Application Gateway Ingress Controller, you are required to input a Base64 encoded JSON string for the service principal for the selected subscription.

You can generate one with command `az ad sp create-for-rbac --sdk-auth | base64 -w0`.  **Note: on macOS, omit the `-w0` flag**.

