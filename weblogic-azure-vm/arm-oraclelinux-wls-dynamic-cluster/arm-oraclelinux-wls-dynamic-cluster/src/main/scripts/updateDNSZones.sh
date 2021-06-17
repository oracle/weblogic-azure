#!/bin/bash
# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#

export resourceGroup=$1
export zoneName=$2
export recordSetNames=$3
export targetResources=$4
export lenRecordset=$5
export lenTargets=$6
export ttl=${7}
export cnameRecordSetNames=${8}
export cnameAlias=${9}
export lenCnameRecordSetNames=${10}
export lenCnameAlias=${11}

if [[ ${lenRecordset} != ${lenTargets} ]]; then
    echo "Error: number of A record set names is not equal to that of target resources."
    exit 1
fi

if [[ ${lenCnameRecordSetNames} != ${lenCnameAlias} ]]; then
    echo "Error: number of CNAME record set names is not equal to that of alias."
    exit 1
fi

# check if the zone exist
az network dns zone show -g ${resourceGroup} -n ${zoneName}

# query name server for testing
nsforTest=$(az network dns record-set ns show -g ${resourceGroup} -z ${zoneName} -n @ --query "nsRecords"[0].nsdname -o tsv)
echo name server: ${nsforTest}

if [ ${lenRecordset} -gt 0 ]; then
    recordSetNamesArr=$(echo $recordSetNames | tr "," "\n")
    targetResourcesArr=$(echo $targetResources | tr "," "\n")

    index=0
    for record in $recordSetNamesArr; do
        count=0
        for target in $targetResourcesArr; do
            if [ $count -eq $index ]; then
                echo Create A record with name: $record, target IP: $target
                az network dns record-set a create \
                    -g ${resourceGroup} \
                    -z ${zoneName} \
                    -n ${record} \
                    --target-resource ${target} \
                    --ttl ${ttl}

                nslookup ${record}.${zoneName} ${nsforTest}
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

if [ ${lenCnameRecordSetNames} -gt 0 ];then
    cnameRecordSetArr=$(echo $cnameRecordSetNames | tr "," "\n")
    cnameRecordAliasArr=$(echo $cnameAlias | tr "," "\n")

    index=0
    for record in $cnameRecordSetArr; do
        count=0
        for target in $cnameRecordAliasArr; do
            if [ $count -eq $index ]; then
                echo Create CNAME record with name: $record, alias: $target
                az network dns record-set cname create \
                    -g ${resourceGroup} \
                    -z ${zoneName} \
                    -n ${record} \
                    --ttl ${ttl}

                az network dns record-set cname set-record \
                    -g ${resourceGroup} \
                    -z ${zoneName} \
                    --cname ${target} \
                    --record-set-name ${record}

                nslookup ${record}.${zoneName} ${nsforTest}
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
