package com.oracle.azure.weblogic.security.util;

import com.oracle.azure.weblogic.HostNameValues;
import weblogic.security.utils.SSLCertUtility;

public class WebLogicCustomHostNameVerifier implements weblogic.security.SSL.HostnameVerifier
{
    public boolean verify(String urlHostname, javax.net.ssl.SSLSession session)
    {
        String commonName = SSLCertUtility.getCommonName(session);
        debug("commonName: "+commonName);
        debug("urlHostname: "+urlHostname);
        
        String hostNameMatchStartString = new StringBuilder(HostNameValues.getDnsLabelPrefix().toLowerCase()).append("0").toString();
        String hostNameMatchEndString = new StringBuilder(HostNameValues.getWlsDomainName().toLowerCase())
                                            .append(".")
                                            .append(HostNameValues.getAzureResourceGroupRegion().toLowerCase())
                                            .append(".")
                                            .append(HostNameValues.azureVMExternalDomainName.toLowerCase()).toString();
        
		String vmNameSubString = new StringBuilder(HostNameValues.getGlobalResourceNameSuffix()).toString();
        debug("vmNameSubString:"+vmNameSubString);        
        
        if(commonName.equalsIgnoreCase(urlHostname))
        {
            debug("urlhostname matching certificate common name");
            return true;
        }
        else
        if(commonName.startsWith(HostNameValues.getAdminVMNamePrefix()) && urlHostname.contains(vmNameSubString))
        {
          	debug("matching with certificate common name and vmname");
           	return true;
        }        
        else
        if(commonName.equalsIgnoreCase(HostNameValues.getAdminInternalHostName()))
        {
            debug("urlhostname matching certificate common name: "+HostNameValues.getAdminInternalHostName()+","+commonName);
            return true;            
        }
        else
        if(commonName.equalsIgnoreCase(HostNameValues.getAdminExternalHostName()))
        {
            debug("urlhostname matching certificate common name: "+HostNameValues.getAdminExternalHostName()+","+commonName);
            return true;            
        }
        else
        if(commonName.equalsIgnoreCase(HostNameValues.getAdminDNSZoneName()))
        {
            debug("adminDNSZoneName matching certificate common name: "+HostNameValues.getAdminDNSZoneName()+","+commonName);
            return true;            
        }
        else
        if(commonName.startsWith(hostNameMatchStartString) && commonName.endsWith(hostNameMatchEndString))
        {
            return true;
        }
        
        return false;
    }
    
    private void debug(String debugStatement)
    {
        if(HostNameValues.isDebugEnabled())
            System.out.println(debugStatement);
    }
}

