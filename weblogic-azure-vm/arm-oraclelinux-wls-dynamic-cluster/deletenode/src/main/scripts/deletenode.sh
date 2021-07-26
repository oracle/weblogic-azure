#!/bin/bash
# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
#Function to output message to StdErr
function echo_stderr ()
{
    echo "$@" >&2
}

#Function to display usage message
function usage()
{
  echo_stderr "./deletenode.sh <wlsUserName> <wlsPassword> <managedVMNames> <forceShutDown> <wlsAdminHost> <wlsAdminPort> <oracleHome> <managedServerPrefix> <deletingCacheServerNames>"
}

function validateInput()
{
    if [[ -z "$wlsUserName" || -z "$wlsPassword" ]]
    then
        echo_stderr "wlsUserName or wlsPassword is required. "
        exit 1
    fi

    if [ -z "$managedVMNames" ];
    then
        echo_stderr "managedVMNames is required. "
    fi

    if [ -z "$wlsForceShutDown" ];
    then
        echo_stderr "wlsForceShutDown is required. "
    fi

    if [ -z "$wlsAdminHost" ];
    then
        echo_stderr "wlsAdminHost is required. "
    fi

    if [ -z "$wlsAdminPort" ];
    then
        echo_stderr "wlsAdminPort is required. "
    fi

    if [ -z "$oracleHome" ];
    then
        echo_stderr "oracleHome is required. "
    fi

    if [ -z "$managedServerPrefix" ];
    then
        echo_stderr "managedServerPrefix is required. "
    fi

    if [ -z "$deletingCacheServerNames" ];
    then
        echo_stderr "deletingCacheServerNames is required. "
    fi
}

#Function to cleanup all temporary files
function cleanup()
{
    echo "Cleaning up temporary files..."
    rm -f ${wlsDomainsPath}/*.py
    echo "Cleanup completed."
}

#This function to delete machines
function delete_machine_model()
{
    arrServerMachineNames=$(echo $managedVMNames | tr "," "\n")
    hasClient="false" # if there is client machine, have to shutdown and start cluster1
    for machine in $arrServerMachineNames
    do
        if [[ "${machine}" =~ ^${managedServerPrefix}StorageVM[0-9]+$ ]];
        then 
            continue
        else
            hasClient="true"
            break
        fi
    done
    
    echo "Deleting managed server machine name model for $managedVMNames"
    cat <<EOF >${wlsDomainsPath}/delete-machine.py
connect('$wlsUserName','$wlsPassword','t3://$wlsAdminURL')
try:
    edit()
    startEdit()
EOF

    if [[ "${hasClient}" == "true" ]]; then 
    cat <<EOF >>${wlsDomainsPath}/delete-machine.py
    shutdown('$wlsClusterName', 'Cluster')
EOF
    fi

    for machine in $arrServerMachineNames
    do
        if [[ -n ${managedServerPrefix} && "${machine}" =~ ^${managedServerPrefix}StorageVM[0-9]+$ ]];
        then 
            # machine name of cache machine
            machineName=${machine}
        else
            # machine name of application machine
            machineName="machine-"${machine}
        fi
        echo "deleting name model for ${machineName}"
        cat <<EOF >>${wlsDomainsPath}/delete-machine.py
    editService.getConfigurationManager().removeReferencesToBean(getMBean('/Machines/${machineName}'))
    cmo.destroyMachine(getMBean('/Machines/${machineName}'))
EOF
    done

    cat <<EOF >>${wlsDomainsPath}/delete-machine.py
    save()
    activate()
except:
    stopEdit('y')
    sys.exit(1)
EOF

    if [[ "${hasClient}" == "true" ]]; then
    cat <<EOF >>${wlsDomainsPath}/delete-machine.py
try: 
    start('$wlsClusterName', 'Cluster')
except:
    dumpStack()
EOF
    fi

    cat <<EOF >>${wlsDomainsPath}/delete-machine.py
disconnect()
EOF
}

#This function to check admin server status 
function wait_for_admin()
{
    #check admin server status
    count=1
    CHECK_URL="http://$wlsAdminURL/weblogic/ready"
    status=`curl --insecure -ILs $CHECK_URL | tac | grep -m1 HTTP/1.1 | awk {'print $2'}`
    echo "Check admin server status"
    while [[ "$status" != "200" ]]
    do
    echo "."
    count=$((count+1))
    if [ $count -le 30 ];
    then
        sleep 1m
    else
        echo "Error : Maximum attempts exceeded while checking admin server status"
        exit 1
    fi
    status=`curl --insecure -ILs $CHECK_URL | tac | grep -m1 HTTP/1.1 | awk {'print $2'}`
    if [ "$status" == "200" ];
    then
        echo "WebLogic Server is running..."
        break
    fi
    done  
}

function delete_cache_server()
{
    if [[ -z "$deletingCacheServerNames" || "$deletingCacheServerNames" == "[]" ]]; then
        return
    fi

    echo "Deleting managed server name model for $deletingCacheServerNames"
    cat <<EOF >${wlsDomainsPath}/delete-server.py
connect('$wlsUserName','$wlsPassword','t3://$wlsAdminURL')
try:
    edit()
    startEdit()
EOF

arrCacheServerNames=$(echo $deletingCacheServerNames | tr "," "\n")
for server in $arrCacheServerNames
do
    echo "deleting name model for $server"
    cat <<EOF >>${wlsDomainsPath}/delete-server.py
    shutdown('$server', 'Server',ignoreSessions='true',force='$wlsForceShutDown')
    editService.getConfigurationManager().removeReferencesToBean(getMBean('/MigratableTargets/$server (migratable)'))
    cd('/')
    cmo.destroyMigratableTarget(getMBean('/MigratableTargets/$server (migratable)'))
    cd('/Servers/$server')
    cmo.setCluster(None)
    cmo.setMachine(None)
    editService.getConfigurationManager().removeReferencesToBean(getMBean('/Servers/$server'))
    cd('/')
    cmo.destroyServer(getMBean('/Servers/$server'))
EOF
done

cat <<EOF >>${wlsDomainsPath}/delete-server.py
    save()
    activate()
except:
    stopEdit('y')
    sys.exit(1)
   
disconnect()
EOF

    . $oracleHome/oracle_common/common/bin/setWlstEnv.sh

    echo "Start to delete managed server $deletingCacheServerNames"
    sudo chown -R ${username}:${groupname} ${wlsDomainsPath}
    runuser -l oracle -c ". $oracleHome/oracle_common/common/bin/setWlstEnv.sh; java $WLST_ARGS weblogic.WLST ${wlsDomainsPath}/delete-server.py"
    if [[ $? != 0 ]]; then
            echo "Error : Deleting managed server $deletingCacheServerNames failed"
            exit 1
    fi
    echo "Complete deleting managed server $deletingCacheServerNames"
}

function delete_managed_machine()
{
    . $oracleHome/oracle_common/common/bin/setWlstEnv.sh

    echo "Start to delete managed server machine $managedVMNames"
    sudo chown -R ${username}:${groupname} ${wlsDomainsPath}
    runuser -l oracle -c ". $oracleHome/oracle_common/common/bin/setWlstEnv.sh; java $WLST_ARGS weblogic.WLST ${wlsDomainsPath}/delete-machine.py"
    if [[ $? != 0 ]]; then
            echo "Error : Deleting machine $managedVMNames failed"
            exit 1
    fi
    echo "Complete deleting managed server machine $managedVMNames"
}

#main script starts here
# store arguments in a special array
args=("$@")
# get number of elements
ELEMENTS=${#args[@]}

# echo each element in array
# for loop
for ((i = 0; i < $ELEMENTS; i++)); do
    echo "ARG[${args[${i}]}]"
done

if [ $# -ne 9 ]
then
    usage
	exit 1
fi

wlsUserName=$1
wlsPassword=$2
managedVMNames=$3
wlsForceShutDown=$4
wlsAdminHost=$5
wlsAdminPort=$6
oracleHome=$7
managedServerPrefix=$8
deletingCacheServerNames=$9
wlsAdminURL=$wlsAdminHost:$wlsAdminPort
hostName=`hostname`
wlsClusterName="cluster1"
username="oracle"
groupname="oracle"
wlsDomainsPath="/u01/domains"

validateInput

cleanup

wait_for_admin

delete_cache_server

delete_machine_model

delete_managed_machine

cleanup
