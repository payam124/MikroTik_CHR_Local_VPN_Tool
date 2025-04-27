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
    :global AACHRLicenseLevel "P1"

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





    # More advanced setting, do not change if you are not sure
    :global AAWinboxPort "8291"
    :global AASSHPort "22"

    :global AANTPServerPool ""0.pool.ntp.org,1.pool.ntp.org,2.pool.ntp.org""
    :global AATimeZone "UTC"

    :global AAMikroTikName "CHR-VPN-USER"

    # The following IP is set on ether3 of MikroTik. Connected device will use that as GW
    :global AALanIPMT "192.168.190.1/24"
    :global AALANNetMT "192.168.190.0/24"

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
    :set (($AADestPBR->"ether1")->($AAVPNSSTPServer . "/32")) $AAVPNSSTPName 
    :set (($AADestPBR->"ether1")->($AAPrivateVPNOvpnServer . "/32")) $AAPrivateVPNOvpnName 

    :global AADNSPrivateServer "192.168.1.1"
    :global AADNSPriavateRedirectEnabled "0"
    :global AADNSPrivateRegx "yourlocaldomain.com|yoursecondlocaldomain.net"
    :global AADNSPrivateServerGW "$AAPrivateVPNOvpnName"

    #to check local DNS cache and flush if any of the unwanted records pops
    :global AADNSCacheWatcherEnabled "0"
    :global AADNSCacheWatcherRegex "192.168.*|172.16\..*|10\..*"

}
