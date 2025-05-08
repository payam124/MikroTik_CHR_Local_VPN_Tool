{
    # default admin user will be dsiabled and this new  user will be created
    :global AAnewAdminUser "replace-me"
    :global AAnewAdminPass "replace-me"
    
    # This user will have minimum access
    :global AAUserUser "replace-me"
    :global AAuserPass "replace-me"

    # Add URL to the SSH key to be used on the device. if you don't have it, leave random string here. it will fail safe
    :global AASSHKeyLink "replace-me"

    #Add your MikrTik User and password (mikrotik.com) to get evaluation license for your CHR
    :global AAMikroTikAccount "replace-me"
    :global AAMikroTikPass "replace-me"
    :global AACHRLicenseLevel "p1"

    #SSTP First VPN
    :global AAVPNSSTPServer "10.255.1.1"
    :global AAVPNSSTPServerUser "replace-me"
    :global AAVPNSSTPServerPass "replace-me"
    :global AAVPNSSTPName "V_VPN_SSTP"
    #OVPN 2nd VPN
    :global AAPrivateVPNOvpnServer "10.255.2.2"
    :global AAPrivateVPNPvpnUser "replace-me"
    :global AAPrivateVPNOvpnPass "replace-me"
    :global AAPrivateVPNOvpnName "V_VPN_OVPN"
    
    :global AAEnableNextDNS "0"
    :global AANextDNSID "replace-me"
    # if not used Next DNS, use public DNS servers
    :global AANNormalDNS "1.1.1.1,9.9.9.9"





    # More advanced setting, do not change if you are not sure
    :global AAWinboxPort "8291"
    :global AASSHPort "22"

    :global AANTPServerPool ""0.pool.ntp.org,1.pool.ntp.org,2.pool.ntp.org""
    :global AATimeZone "UTC"

    :global AAMikroTikName "CHR-VPN-USER"

    # The following IP is set on ether3 of MikroTik. Connected device will use that as GW
    :global AALanIPMT "192.168.190.1/24"
    :global AALANNetMT "192.168.190.0/24"

    # Set destination IP for each ethernt interfaces. for VPNs, use their interface name as set above ($AAVPNSSTPName and $AAPrivateVPNOvpnName)
    :global AADestPBR {
        "ether1"={
            "10.0.0.1/32"="safe_dns_server";
            "10.0.0.0/24"="safe_database_network";
        };
        "ether2"={
            "10.1.0.0/24"="safe_internal_services";
            "10.1.1.0/24"="safe_monitoring_tools";
        };
    }
    # Assume the VPNs are required to connect over ether1 (or automatically ether2 if ether1 is not avaiable)
    :set (($AADestPBR->"ether1")->($AAVPNSSTPServer . "/32")) $AAVPNSSTPName 
    :set (($AADestPBR->"ether1")->($AAPrivateVPNOvpnServer . "/32")) $AAPrivateVPNOvpnName 

    # If you have in internal DNS resolver for certain local domain which are not exposed on the internet, you can create a DNS forwarder
    # based on the Layer 7 packet for UDP packets contain  the target domain(s) and forward them to the local DNS server
    :global AADNSPrivateServer "192.168.1.1"
    :global AADNSPriavateRedirectEnabled "0"
    :global AADNSPrivateRegx "yourlocaldomain.com|yoursecondlocaldomain.net"
    :global AADNSPrivateServerGW "$AAPrivateVPNOvpnName"

    #to check local DNS cache and flush if any of the unwanted records pops
    :global AADNSCacheWatcherEnabled "0"
    :global AADNSCacheWatcherRegex "192.168.*|172.16\..*|10\..*"

    #list interfaces that should be configured as WAN (DHCP, packet mark, ...
    #sometimes we can not get both interfaces up, so we can modify it here
    :global AAWanInterfaces "ether1,ether2"
    :global AALANInterface "ether3"
    


}
