### Obtain the Managed Identity

The parameter `dbIdentity` stands for Managed Identity that can connect to database. 

Firstly, obtain Managed Identity Id with command:

```bash
resourceID=$(az identity show --resource-group myResourceGroup --name myManagedIdentity --query id --output tsv)
```

The value muse be the following:

```json
{
    "dbIdentity": {
        "value": {
            "type": "UserAssigned",
            "userAssignedIdentities": {
                "${resourceID}": {}
            }
        }
    }
}
```