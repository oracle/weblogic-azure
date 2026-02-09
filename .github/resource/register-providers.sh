for provider in \
  "Microsoft.Sql" \
  "Microsoft.Compute" \
  "Microsoft.Network" \
  "Microsoft.Storage" \
  "Microsoft.KeyVault" \
  "Microsoft.DBforMySQL" \
  "Microsoft.DBforPostgreSQL"
do
  echo "Registering provider: $provider"
  az provider register --namespace "$provider"
done

echo ""
echo "Waiting for registration to complete..."
sleep 30

for provider in \
  "Microsoft.Sql" \
  "Microsoft.Compute" \
  "Microsoft.Network" \
  "Microsoft.Storage" \
  "Microsoft.KeyVault" \
  "Microsoft.DBforMySQL" \
  "Microsoft.DBforPostgreSQL"
do
  state=$(az provider show --namespace "$provider" --query "registrationState" -o tsv)
  echo "$provider: $state"
done
