for img in \
  "ohs-122140-jdk8-ol76:ohs-122140-jdk8-ol76" \
  "ohs-122140-jdk8-ol74:ohs-122140-jdk8-ol74" \
  "ohs-122140-jdk8-ol73:ohs-122140-jdk8-ol73" \
  "weblogic-141200-jdk21-ol94:owls-141200-jdk21-ol94" \
  "weblogic-141200-jdk21-ol810:owls-141200-jdk21-ol810" \
  "weblogic-141200-jdk17-ol94:owls-141200-jdk17-ol94" \
  "weblogic-141200-jdk17-ol810:owls-141200-jdk17-ol810" \
  "weblogic-141100-jdk11-ol91:owls-141100-jdk11-ol91" \
  "weblogic-141100-jdk11-ol87:owls-141100-jdk11-ol87" \
  "weblogic-141100-jdk11-ol76:owls-141100-jdk11-ol7" \
  "weblogic-141100-jdk8-ol91:owls-141100-jdk8-ol91" \
  "weblogic-141100-jdk8-ol87:owls-141100-jdk8-ol87" \
  "weblogic-141100-jdk8-ol76:owls-141100-jdk8-ol7" \
  "weblogic-141100-jdk11-rhel87:owls-141100-jdk11-rhel87" \
  "weblogic-141100-jdk11-rhel76:owls-141100-jdk11-rhel76" \
  "weblogic-141100-jdk8-rhel87:owls-141100-jdk8-rhel87" \
  "weblogic-141100-jdk8-rhel76:owls-141100-jdk8-rhel76" \
  "weblogic-122140-jdk8-ol91:owls-122140-jdk8-ol91" \
  "weblogic-122140-jdk8-ol87:owls-122140-jdk8-ol87" \
  "weblogic-122140-jdk8-ol76:owls-122140-jdk8-ol7" \
  "weblogic-122140-jdk8-rhel87:owls-122140-jdk8-rhel87" \
  "weblogic-122140-jdk8-rhel76:owls-122140-jdk8-rhel76"
do
  offer="${img%%:*}"
  plan="${img##*:}"
  echo "Accepting terms for offer=$offer plan=$plan"
  az vm image terms accept --publisher oracle --offer "$offer" --plan "$plan"
done
