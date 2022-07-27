# Copyright (c) 2021, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

import sys

def usage():
    print(sys.argv[0] + '-user <domain-user> -password <domain-password> -t3ChannelAddress <address of the cluster> -t3ChannelPort <t3 channel port>')

if len(sys.argv) < 4:
    usage()
    sys.exit(0)

#domainUser is hard-coded to weblogic. You can change to other name of your choice. Command line paramter -user.
domainUser = 'weblogic'
#domainPassword will be passed by Command line parameter -password.
domainPassword = None
t3ChannelPort = None
t3ChannelAddress = None

i = 1
while i < len(sys.argv):
    if sys.argv[i] == '-user':
        domainUser = sys.argv[i + 1]
        i += 2
    elif sys.argv[i] == '-password':
        domainPassword = sys.argv[i + 1]
        i += 2
    elif sys.argv[i] == '-t3ChannelAddress':
        t3ChannelAddress = sys.argv[i + 1]
        i += 2
    elif sys.argv[i] == '-t3ChannelPort':
        t3ChannelPort = sys.argv[i + 1]
        i += 2
    else:
        print('Unexpected argument switch at position ' + str(i) + ': ' + str(sys.argv[i]))
        usage()
        sys.exit(1)

t3ConnectionUri='t3://'+t3ChannelAddress+':'+t3ChannelPort
connect(domainUser, domainPassword, t3ConnectionUri)
myapps=cmo.getAppDeployments()
inactiveApp=0
for app in myapps:
        bean=getMBean('/AppDeployments/'+app.getName()+'/Targets/')
        targetsbean=bean.getTargets()
        for target in targetsbean:
                domainRuntime()
                cd('AppRuntimeStateRuntime/AppRuntimeStateRuntime')
                appstatus=cmo.getCurrentState(app.getName(),target.getName())
                if appstatus != 'STATE_ACTIVE':
                    inactiveApp=inactiveApp+1
                serverConfig()

# TIGHT COUPLING: this exact print text is expected to indicate a successful return.
if inactiveApp == 0:
    print("Summary: all applications are active!")
else:
    print("Summary: number of inactive application: " + str(inactiveApp) + '.')
