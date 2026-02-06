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
  az provider register --namespace "$provider" --wait
done

echo ""
echo "Verifying provider registration status..."

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
  if [ "$state" != "Registered" ]; then
    echo "WARNING: $provider is not fully registered yet (state: $state)"
  fi
done

echo ""
echo "Provider registration complete!"
