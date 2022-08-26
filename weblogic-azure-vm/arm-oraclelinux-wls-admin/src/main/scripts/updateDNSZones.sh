#!/bin/bash
# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

# Description
#  This script updates the Azure DNS Zones used for configuring DNS for WebLogic Admin Server and Azure Application Gateway.

# Inputs:
# RESOURCE_GROUP_NAME
# DNS_ZONE_NAME
# DNS_RECORDSET_NAMES
# DNS_TARGET_RESOURCES
# DNS_RECORD_NAMES_LENGTH
# DNS_TARGET_RESOURCES_LENGTH
# DNS_RECORD_TTL
# DNS_CNAME_RECORDSET_NAMES
# DNS_CNAME_ALIAS
# DNS_CNAME_RECORDSET_LENGTH
# DNS_CNAME_ALIAS_LENGTH
# MANAGED_IDENTITY_ID

if [[ ${DNS_RECORD_NAMES_LENGTH} != ${DNS_TARGET_RESOURCES_LENGTH} ]]; then
    echo "Error: number of A record set names is not equal to that of target resources."
    exit 1
fi

if [[ ${DNS_CNAME_RECORDSET_LENGTH} != ${DNS_CNAME_ALIAS_LENGTH} ]]; then
    echo "Error: number of CNAME record set names is not equal to that of alias."
    exit 1
fi

# check if the zone exist
az network dns zone show -g ${RESOURCE_GROUP_NAME} -n ${DNS_ZONE_NAME}

# query name server for testing
nsforTest=$(az network dns record-set ns show -g ${RESOURCE_GROUP_NAME} -z ${DNS_ZONE_NAME} -n @ --query "nsRecords"[0].nsdname -o tsv)
echo name server: ${nsforTest}

if [ ${DNS_RECORD_NAMES_LENGTH} -gt 0 ]; then
    recordSetNamesArr=$(echo $DNS_RECORDSET_NAMES | tr "," "\n")
    targetResourcesArr=$(echo $DNS_TARGET_RESOURCES | tr "," "\n")

    index=0
    for record in $recordSetNamesArr; do
        count=0
        for target in $targetResourcesArr; do
            if [ $count -eq $index ]; then
                echo Create A record with name: $record, target IP: $target
                az network dns record-set a create \
                    -g ${RESOURCE_GROUP_NAME} \
                    -z ${DNS_ZONE_NAME} \
                    -n ${record} \
                    --target-resource ${target} \
                    --ttl ${DNS_RECORD_TTL}

                nslookup ${record}.${DNS_ZONE_NAME} ${nsforTest}
                if [ $? -eq 1 ];then
                    echo Error: failed to create record with name: $record, target Id: $target
                    exit 1
                fi
            fi

            count=$((count + 1))
        done

        index=$((index + 1))
    done
fi

if [ ${DNS_CNAME_RECORDSET_LENGTH} -gt 0 ];then
    cnameRecordSetArr=$(echo $DNS_CNAME_RECORDSET_NAMES | tr "," "\n")
    cnameRecordAliasArr=$(echo $DNS_CNAME_ALIAS | tr "," "\n")

    index=0
    for record in $cnameRecordSetArr; do
        count=0
        for target in $cnameRecordAliasArr; do
            if [ $count -eq $index ]; then
                echo Create CNAME record with name: $record, alias: $target
                az network dns record-set cname create \
                    -g ${RESOURCE_GROUP_NAME} \
                    -z ${DNS_ZONE_NAME} \
                    -n ${record} \
                    --ttl ${DNS_RECORD_TTL}

                az network dns record-set cname set-record \
                    -g ${RESOURCE_GROUP_NAME} \
                    -z ${DNS_ZONE_NAME} \
                    --cname ${target} \
                    --record-set-name ${record}

                nslookup ${record}.${DNS_ZONE_NAME} ${nsforTest}
                if [ $? -eq 1 ];then
                    echo Error: failed to create CNAME record with name: $record, alia: $target
                    exit 1
                fi
            fi

            count=$((count + 1))
        done

        index=$((index + 1))
    done
fi

# delete user assigned managed identity

az identity delete --ids ${MANAGED_IDENTITY_ID} 
