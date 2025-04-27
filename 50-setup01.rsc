{

###### General
:put "### General SEtting"
/system/ntp/client/ set enabled=yes \
servers=$AANTPServerPool
/system clock
set time-zone-autodetect=no time-zone-name=$AATimeZone

{
/system identity set name=$AAMikroTikName
}

/ip service
set telnet disabled=yes
set ftp disabled=yes
set api disabled=yes
set api-ssl disabled=yes


:do {    /tool/graphing/interface add } on-error={ :put "graph for interfaces exist"}

:local resourceIds [/tool graphing/resource find where allow-address="0.0.0.0/0"]

:if ([:len $resourceIds] = 0) do={
    /tool graphing/resource add allow-address=0.0.0.0/0 disabled=no store-on-disk=yes
    :local msg "Resource graph with 0.0.0.0/0 added."
    :log info $msg
    :put $msg
} else={
    :foreach id in=$resourceIds do={
        /tool graphing/resource set $id disabled=no store-on-disk=yes
    }
    :local msg ("Updated " . [:len $resourceIds] . " existing resource graph entries to correct settings.")
    :log info $msg
    :put $msg
}



:put "### logging"

{

    #logging, it is important to persist logs on disk befor any operation
    :log info "$app:setting logging"
    /system logging action set 1 disk-file-count=20
    :local warnFile "log-warn-error"
   :if ([:len [/file/find name=flash]] >0 && [/file/get value-name=type [find name="flash"]] ="disk") do={
       :set warnFile ("flash/".$warnFile);
   }

    :local actionName "diskWarnError"
    # Check if the logging action exists
    :if ([:len [/system logging action find where name=$actionName]] = 0) do={
        :log info ("Creating logging action: " . $actionName)
        /system logging action add name=$actionName disk-file-name=$warnFile disk-file-count=3 target=disk
        :log info ("Logging action " . $actionName . " created successfully.")
    } else={
        :log info ("Logging action " . $actionName . " already exists. Updating settings.")
        /system logging action set [find where name=$actionName] disk-file-name=$warnFile disk-file-count=3 target=disk
        :log info ("Logging action " . $actionName . " updated successfully.")
    }



    :local LoggingRules {{topic="critical";action="disk"};
                        {topic="bridge,debug";action="disk"};
                        {topic="bridge,debug";action="memory"};                        
                        {topic="error";action="disk"};
                        {topic="info";action="disk"};
                        {topic="warning";action="disk"};
                        {topic="warning";action="diskWarnError"};
                        {topic="error";action="diskWarnError"};
                        };
    :foreach Rule in=$LoggingRules do={
        #:put ($Rule->"topic")
        #:put ($Rule->"action")
        #:put [:len [/system/logging/find topics=[:toarray ($Rule->"topic")] action=($Rule->"action")]]
        #:put "delay"
        #:delay 1
        :do {

            :if ( [:len [/system/logging/find topics=[:toarray ($Rule->"topic")] action=($Rule->"action")]] =0 ) do={
                /system logging add topics=[:toarray ($Rule->"topic")] action=($Rule->"action")
            } else={
                :put ("the following logging rule exists: topic=".($Rule->"topic")." action=".($Rule->"action"))
                :log warning ("$app:the following logging rule exists: topic=".($Rule->"topic")." action=".($Rule->"action"))
            }
        } on-error={ 
            :local msg "error adding topic=$($Rule->"topic") action=$($Rule->"action")"
            :log warning $msg
            :put $msg
        }

    }
   
}


:put "### interface comment"
#Initial Setup
/interface ethernet
set [ find default-name=ether1 ] comment=uplink_WiFi disable-running-check=no
set [ find default-name=ether2 ] comment=Uplink_Ethernet disable-running-check=no
set [ find default-name=ether3 ] comment=PC_LAN disable-running-check=no

:put "### add ip address"
# Define the IP addresses and their corresponding interfaces

:local ipAddresses [:toarray ""]
:set ($ipAddresses->"127.0.0.1/24") "lo";
:set ($ipAddresses->$AALanIPMT) "ether3";


# Loop through the IP addresses and add them to the interfaces if not already assigned
:foreach ip,interface in=$ipAddresses do={
    :if ([:len [/ip address find where address=$ip && interface=$interface]] = 0) do={
        :local msg ("Adding IP address " . $ip . " to interface " . $interface)
        :log info $msg
        :put $msg
        /ip address add address=$ip interface=$interface
    } else={
        :local msg ("IP address " . $ip . " is already assigned to interface " . $interface)
        :log info $msg
        :put $msg
    }
}

#remove unknown interface lists membes
/interface list member remove [find where interface~"\\*"]

:put "### add dhcp client list"
#this stage with default gw, and DNS but later to be removed
# Define the interfaces for DHCP clients
:local dhcpInterfaces {"ether1"; "ether2"}

# Loop through the interfaces and add DHCP clients if not already configured
:foreach Dinterface in=$dhcpInterfaces do={
    :if ([:len [/ip dhcp-client find where interface=$Dinterface]] = 0) do={
        :local msg ("Adding DHCP client to interface " . $interfacDinterface)
        :log info $msg
        :put $msg
        /ip dhcp-client add interface=$Dinterface
    } else={
        :local msg ("DHCP client already exists on interface " . $Dinterface)
        :log info $msg
        :put $msg
    }
}




# wnat nat interaca list
# DNS interface list
# allow stablisehd related input, forward
# allow DNS local
# nlock other DNS
# activate remote request DNS, explicity add 1.1.1.1, 99.9.
## disable DNS by DHCP
## Possibly we may not need default rooute frm DHCP servers 

#/ip dns
#set allow-remote-requests=yes servers=1.1.1.1,9.9.9.9

:put "### add inteface lists"
:local interfaceLists {"WAN_NAT"; "DNS_ALLOW"}

# Loop through the list and create only if it doesn't exist
:foreach listName in=$interfaceLists do={
    :if ([:len [/interface list find where name=$listName]] = 0) do={
        :log info ("Creating interface list: " . $listName)
        /interface list add name=$listName
    } else={
        :log info ("Interface list already exists: " . $listName)
    }
}


# Define the interfaces and their corresponding lists
:local interfaceMembers {
    "ether1"="WAN_NAT";
    "ether2"="WAN_NAT";
    "ether3"="DNS_ALLOW"
}

# Loop through the interfaces and add them to the lists if not already a member
:foreach Dinterface,list in=$interfaceMembers do={
    :if ([:len [/interface list member find where interface=$Dinterface && list=$list]] = 0) do={
        :log info ("Adding interface " . $Dinterface . " to list " . $list)
        /interface list member add interface=$Dinterface list=$list
    } else={
        :log info ("Interface " . $Dinterface . " is already in list " . $list)
    }
}

:put "### add basic firewall and DNS"
/ip firewall filter add action=accept chain=forward connection-state=established,related comment="Established/Related"
/ip firewall filter add action=accept chain=input connection-state=established,related
/ip firewall filter add action=accept chain=input dst-port=53 in-interface-list=DNS_ALLOW protocol=tcp comment="DNS only where requires"
/ip firewall filter add action=accept chain=input dst-port=53 in-interface-list=DNS_ALLOW protocol=udp
/ip firewall filter add action=drop chain=input dst-port=53 protocol=tcp
/ip firewall filter add action=drop chain=input dst-port=53 protocol=udp

#NAT outgoing interfaces
# Check if the NAT rule exists, and add it if it doesn't
:if ([:len [/ip firewall nat find where chain="srcnat" && action="masquerade" && out-interface-list="WAN_NAT"]] = 0) do={
    :log info "Adding NAT masquerade rule for out-interface-list=WAN_NAT"
    /ip firewall nat add action=masquerade chain=srcnat out-interface-list=WAN_NAT
} else={
    :local msg "NAT masquerade rule for out-interface-list=WAN_NAT already exists"
    :log info $msg
    :put $msg
}


:put "### allow DNS qury"
/ip dns set allow-remote-requests=yes


:put "### setup VPNS"
# Setup VPNs
#contiue
# DONT FORGET‌PASSWORD
# Check if the SSTP VPN client exists, and add it if it doesn't
:if ([:len [/interface sstp-client find where name="$AAVPNSSTPName"]] = 0) do={
    :local msg "Adding SSTP VPN client with name $AAVPNSSTPName" 
    :log info $msg
    :put $msg

    /interface sstp-client add connect-to=$AAVPNSSTPServer name=$AAVPNSSTPName profile=default-encryption user=$AAVPNSSTPServerUser password=$AAVPNSSTPServerPass disabled=no
} else={
    :local msg "SSTP VPN client with name $AAVPNSSTPName already exists"
    :log info $msg
    :put $msg
}

# Check if the OVPN client exists, and add it if it doesn't
:if ([:len [/interface ovpn-client find where name="$AAPrivateVPNOvpnName"]] = 0) do={
    :local msg "Adding OVPN client with name $AAPrivateVPNOvpnName"
    :log info $msg
    :put $msg
    /interface ovpn-client add name=$AAPrivateVPNOvpnName connect-to=$AAPrivateVPNOvpnServer use-peer-dns=no user=$AAPrivateVPNPvpnUser password=$AAPrivateVPNOvpnPass disabled=no
} else={
    :local msg "OVPN client with name $AAPrivateVPNOvpnName already exists"
    :log info $msg
    :put $msg    
}

:put "waiting for VPN to be up"
:delay 3
# Define the VPN interfaces and their corresponding lists
:local vpnInterfaceMembers [:toarray ""]
:set ($vpnInterfaceMembers->$AAVPNSSTPName) "WAN_NAT"
:set ($vpnInterfaceMembers->$AAPrivateVPNOvpnName) "WAN_NAT"


#remove unknown interface lists membes
/interface list member remove [find where interface~"\\*"]
# Loop through the VPN interfaces and add them to the lists if not already a member
:foreach VPNinterface,list in=$vpnInterfaceMembers do={
    :if ([:len [/interface list member find where interface=$VPNinterface && list=$list]] = 0) do={
        :local msg ("Adding interface " . $VPNinterface . " to list " . $list)
        :log info $msg
        :put $msg
        /interface list member add interface=$VPNinterface list=$list
    } else={
        :local msg ("Interface " . $VPNinterface . " is already in list " . $list)
        :log info $msg
        :put $msg
    }
}



:put "### setup PBR"

#######################
# PBR
#######################
#delete all
 {
    :local FuncDelPBRAll do={
      /ip firewall mangle remove [find comment ~"^#MLK#PBR#"]
      /ip firewall address-list remove [find comment ~"^#MLK#PBR#"]
      /routing/table remove [find comment ~ "^#MLK#PBR#"]
      /ip/route/remove [find comment ~ "^#MLK#PBR#"]
   }
   $FuncDelPBRAll 
}

{
   :local app "App_set_PBR_v0.84"
   :log debug "$app:started"
   :local interfaces {"$AAPrivateVPNOvpnName";"ether1";"ether2";"ether3";"$AAVPNSSTPName"}
   #:local interfaces {"ether1_X";"ether2_Y"}
   #:local interfaces {"pppoe-out-bell";"ether3_ROGERS"}
   :local commentTag "#MLK#PBR#"
   :local FuncDelPBRAll do={
      /ip firewall mangle remove [find comment ~"^#MLK#PBR#"]
      /ip firewall address-list remove [find comment ~"^#MLK#PBR#"]
   }

   :local FuncDelPBRMangleInt do={
      :if ([:len $commentTag] =0) do={ 
         :log error "$app:FuncDelPBRMangleInt/no commentTag arg"
         :return 1
         #or
         #:local commentTag "#MLK#PBR#"
      }
      #/ip firewall mangle remove [find comment ~"^#MLK#PBR#.*#$interface#"]
      #/ip firewall address-list remove [find comment ~"^#MLK#PBR#.*#$interface#"]
      /ip firewall mangle remove [find comment ~"^$commentTag.*#$interface#"]
      /ip firewall address-list remove [find comment ~"^$commentTag.*#$interface#"]
      
   }
   :local FuncDelPBRRouteInt do={
      :if ([:len $commentTag] =0) do={ 
         :log error "$app:FuncDelPBRRouteInt/no commentTag arg"
         :return 1
         #or
         #:local commentTag "#MLK#PBR#"
      }

      /ip route remove [find comment ~"^$commentTag.*$interface#"]
   }
   :local FuncAddPBRMangleInt do={
      :if ([:len $commentTag] =0) do={ 
         :log error "$app:FuncAddPBRMangleInt/no commentTag agr"
         :return 1
         #or
         #:local commentTag "#MLK#PBR#"
      }

      :local commentTagNewIn ($commentTag."NEWIN#".$interface."#")
      :local commentTagRetFW ($commentTag."RETFW#".$interface."#")
      :local commentTagRetOut ($commentTag."RETO#".$interface."#")
      #for destinations in forwarding. i.e. destinations that need to go out from this particular interface/route
      :local commentTagPDF ($commentTag."PDF#".$interface."#")
      #for destinations in output. i.e. destinations that need to go out from this particular interface/route. Router's generated packet
      :local commentTagPDO ($commentTag."PDO#".$interface."#")
      :local commentTagPSF ($commentTag."PSF#".$interface."#")
      :local commentTagPSO ($commentTag."PSO#".$interface."#")
      
      :local connectionMarkFrom ("MLK-CM-FROM-".$interface)
      :local routeMarkTo ("MLK-RM-TO-".$interface)
      
      :local destAddrList ("MLK-DESTTO-".$interface)
      :local srcAddrList ("MLK-SRCTTO-".$interface)
      #is not interface related (the IPS to be excluded)
      :local dstAddrListExc ("MLK-DESTEXC")
      :local commentTagDstAddrList ($commentTag."Destinations routed through#".$interface."#")
      :local commentTagSrcAddrList ($commentTag."Sources Routed through#".$interface."#")
      #is not interface related
      :local commentTagDstExcAddrList ($commentTag."Destinations Excluded from PBR#") 
      :local commentTagRouteTable ($commentTag."RoutingTable#") 
      
      :local placeBeforeCmd ""
      #the below commands neet more attention, got this error:
      #Script Error: cannot compare if nothing is more than time interval
      #:if (:len [/ip firewall mangle [find comment ~"^#MLK#PBR#"]] >0) do={
      #:if (:len [/ip firewall mangle find comment ~"^#MLK#PBR#"] >0) do={
      #}
      /routing/table/add name=$routeMarkTo comment=$commentTagRouteTable fib
      
      #create address lists for PBR
      /ip firewall address-list add address=255.255.255.0 comment="$commentTagDstAddrList" disabled=yes list=$destAddrList
      /ip firewall address-list add address=255.255.255.0 comment="$commentTagSrcAddrList" disabled=yes list=$srcAddrList
      
      :local excCount [:len [/ip firewall address-list find comment ="$commentTagDstExcAddrList" disabled=yes address=255.255.255.0]]
      #:put "number of exclude adress list is $excCount"
      :if ($excCount=0) do={
         /ip firewall address-list add address=255.255.255.0 comment="$commentTagDstExcAddrList" disabled=yes list=$dstAddrListExc
      }
      #PBR for destinations
      /ip firewall mangle add action=mark-connection chain=prerouting comment=$commentTagPDF connection-state=new dst-address-list=$destAddrList new-connection-mark=$connectionMarkFrom passthrough=yes 
      /ip firewall mangle add action=mark-routing chain=output comment=$commentTagPDO dst-address-list=$destAddrList new-routing-mark=$routeMarkTo passthrough=no
      #PBR for sources
      /ip firewall mangle add action=mark-connection chain=prerouting comment=$commentTagPSF connection-state=new dst-address-list="!$dstAddrListExc" dst-address-type=!local new-connection-mark=$connectionMarkFrom passthrough=yes src-address-list=$srcAddrList ttl=greater-than:1
      /ip firewall mangle add action=mark-routing chain=output comment=$commentTagPSO dst-address-list="!$dstAddrListExc" dst-address-type=!local new-routing-mark=$routeMarkTo passthrough=no src-address-list=$srcAddrList
      
      #PBR, incoming connection
      /ip firewall mangle add action=mark-connection chain=prerouting comment="$commentTagNewIn" connection-state=new in-interface=$interface new-connection-mark=$connectionMarkFrom passthrough=no
      /ip firewall mangle add action=mark-routing chain=prerouting comment="$commentTagRetFW" connection-mark=$connectionMarkFrom in-interface="!$interface" new-routing-mark=$routeMarkTo passthrough=no
      #add dst-address-list=!MLK-DESTEXC to correct tracertoue
      /ip firewall mangle add action=mark-routing chain=output comment="$commentTagRetOut" connection-mark=$connectionMarkFrom new-routing-mark=$routeMarkTo passthrough=no dst-address-list=!MLK-DESTEXC
      
      
      :return $routeMarkTo

   }
   :local FuncAddPBRInt do={
       :if ([:len $commentTag] =0) do={ 
         :log error "$app:FuncDelPBRMangleInt/no commentTag arg"
         :return 1
         #or
         #:local commentTag "#MLK#PBR#"
      }
       :if ([:len $routeMarkTo] =0) do={ 
         :log error "$app:FuncDelPBRMangleInt/no routeMarkTo arg"
         :return 1
      }      
      
      ## add route
      :local commentTagRoutePBR ($commentTag.$interface."#")
      /ip route add distance=1 dst-address=0.0.0.0/0 gateway=$interface disabled=yes routing-table=$routeMarkTo comment="$commentTagRoutePBR" scope=30 target-scope=10
      #add blackhole if the gateway is not responding
      # but there is a problem, when interface is down, the mark route in mangle does not work so it won't mark and so blakchole is meaningless
      #unless add a rule at the end of 2 lines to again match destinations in case interaface is down
      /ip route add distance=200 dst-address=0.0.0.0/0 gateway="" disabled=yes routing-table=$routeMarkTo comment=($commentTagRoutePBR."blackhole") scope=30 suppress-hw-offload=no target-scope=10  blackhole

   }

   :local FuncDelUnknownCon do={
      :local unknownConCount
      :set $unknownConCount [:len [/ip firewall connection  find  connection-mark ~"^\\(unknown" ]]
      :put [:len [/ip firewall connection  find  connection-mark ~"^\\(unknown" ]]
      :if ( $unknownConCount<1) do={
         :log info "$app:FuncDelUnknownCon/no connection with Unknown marks to be deleted"
         #:put "$app: no connection with Unknown marks to be deleted"
         :return 0
      } else={
         :log info "$app:FuncDelUnknownCon/there are $unknownConCount connections with unknown connection mark"
         #:put "$app: there are $unknownConCount connections with unknown connection mark"
         :local unknownCon [/ip firewall connection  find  connection-mark ~"^\\(unknown" ]
         :foreach con in=$unknownCon do={
            :put [/ip firewall connection get  $con]
            :log info ("$app:FuncDelUnknownCon/deleting connection with unknown marks".[:tostr [/ip firewall connection get  $con]])
            /ip firewall connection remove $con
         }
      }
   }

   :foreach interface in=$interfaces do={
      :log debug "$app:$interface"
      #:local foundInterface  [ :len [/interface find name=$interface] ]
      :local foundInterface  [ :len [/interface find name=$interface] ]
      #:set foundInterface :len [/interface find name=$interface]
      #:put $foundInterface
      :log debug "$app: number of interfaces found equal to $interface: $foundInterface"
      :if ($foundInterface=0) do={
         :log error "$app:interface $interface does not exist"
      } else={
         :if ($foundInterface>1) do={
            #should not happen at all
            :log error "$app:number of interfaces found equal to $interface is more than 1!!!: $foundInterface"
         } else={
            $FuncDelPBRMangleInt interface=$interface commentTag=$commentTag
            $FuncDelPBRRouteInt interface=$interface  commentTag=$commentTag
            :local routeMarkTo
            :set $routeMarkTo [$FuncAddPBRMangleInt interface=$interface commentTag=$commentTag]
            $FuncAddPBRInt interface=$interface commentTag=$commentTag routeMarkTo=$routeMarkTo
         }
      }
   }
   $FuncDelUnknownCon
   :log debug "$app:finished"
}

#exclude local LAN from PBR
:put "### exclude local lan from pbr"
/ip firewall address-list add address=$AALANNetMT comment="#MLK#PBR#Destinations Excluded from PBR#" list=MLK-DESTEXC




 :put "### setup backup route for ethernet uplinks"
 
 # Backup routes for both ether1 and ehter2 in case one dos not work
 #first remove existing
/ip route remove  [find comment ~ "#MLK#PBR#ether.#backup_ether"]
#add
/ip route add check-gateway=ping  disabled=yes distance=2 dst-address=0.0.0.0/0 gateway=ether2 routing-table=MLK-RM-TO-ether1 scope=30 suppress-hw-offload=no target-scope=10 comment=#MLK#PBR#ether2#backup_ether1
/ip route add check-gateway=ping  disabled=yes distance=2 dst-address=0.0.0.0/0 gateway=ether1 routing-table=MLK-RM-TO-ether2 scope=30 suppress-hw-offload=no target-scope=10 comment=#MLK#PBR#ether1#backup_ether2
/ip route set check-gateway=ping [find comment ~ "#MLK#PBR#ether"]
 
 :put "### set gateway for related route"
 /ip dhcp-client set  script=":if (\$bound = 1 ) do={\
    \n   /ip route set disabled=no gateway= \$\"gateway-address\" [find comment~ \"^#MLK#PBR#ether1#\"]\
    \n}\
    \n" use-peer-dns=no [find interface=ether1]
:put "### set gateway for related route"
 /ip dhcp-client set  script=":if (\$bound = 1 ) do={\
    \n   /ip route set disabled=no gateway= \$\"gateway-address\" [find comment~ \"^#MLK#PBR#ether2#\"]\
    \n}\
    \n" use-peer-dns=no [find interface=ether2]


# Check if the route exists, and add it if it doesn't
:if ([:len [/ip route find where dst-address="0.0.0.0/0" && gateway="ether1" && routing-table=main ]] = 0) do={
    :local msg "Adding default route with gateway ether1"
    :log info $msg
    :put $msg

    /ip route add comment=default_route_handle_no_active_route disabled=no distance=100 dst-address=0.0.0.0/0 gateway=ether1 routing-table=main scope=30 suppress-hw-offload=no target-scope=10
} else={
    :local msg "Default route with gateway ether1 already exists"
    :log warning $msg
    /terminal style error ; :put $msg ; /terminal style none
}

:put "### Enabl PBR for VPNS"
/ip route set disabled=no [find comment~"#MLK#PBR#V_"]

#activate 
/ip dhcp-client release ether1 
/ip dhcp-client release ether2

#for place before
:delay 1
:put "###change MSS"
:local firstItem [:pick [/ip firewall mangle  find ] 0]
/ip firewall mangle add action=change-mss chain=forward connection-state=new new-mss=1350 protocol=tcp tcp-flags=syn place-before=$firstItem comment="reduce MSS"


:put "###add SHTL destination addresses"

:foreach iface,networks in=$AADestPBR do={
    :local listName ("MLK-DESTTO-" . $iface)
    :local fixedPrefix ("#MLK#PBR#Destinations routed through#" . $iface . "#")
    /ip firewall address-list remove [find  where list=$listName && comment~("^".$fixedPrefix.".")]

    # Loop through IPs inside each interface
    :foreach IP,Comment in=$networks do={
        :do { /ip firewall address-list add address=$IP list=$listName comment=($fixedPrefix . $Comment) } on-error={
            :local msg ("address list exists:  $IP: list:$listName")
            :log warn $msg
            :put $msg
        }
    }
}

:put "### stop and start VPNS"
#stop and start VPNS
/interface sstp-client disable $AAVPNSSTPName
/interface ovpn-client disable $AAPrivateVPNOvpnName
:delay 1
/interface sstp-client enable $AAVPNSSTPName
/interface ovpn-client enable $AAPrivateVPNOvpnName
:delay 5

:put "### set next dns"
#/tool fetch url=https://curl.se/ca/cacert.pem
#/certificate import file-name=cacert.pem
:if ($AAEnableNextDNS=1) do={
    :put "### add nextdns static DNS"
    
    :do {/ip dns static add name=dns.nextdns.io address=45.90.28.0 type=A } on-error {:put "static record for next dns exist"}
    :do { /ip dns static add name=dns.nextdns.io address=45.90.30.0 type=A } on-error {:put "static record for next dns exist"}
    :do { /ip dns static add name=dns.nextdns.io address=2a07:a8c0:: type=AAAA } on-error {:put "static record for next dns exist"}
    :do { /ip dns static add name=dns.nextdns.io address=2a07:a8c1:: type=AAAA } on-error {:put "static record for next dns exist"}
    /ip dns set use-doh-server=("https://dns.nextdns.io/".$AANextDNSID)
}
    


:if ($AADNSPriavateRedirectEnabled=1) do={
    :put "### add l7 DNS redirect for rasana"

    :local L7DNSruleName "dns_local_redirect"
    :local L7DNSruleRegexp $AADNSPrivateRegx

    # Check if the rule exists
    :if ([:len [/ip firewall layer7-protocol find where name=$L7DNSruleName]] > 0) do={
        :log info ("Updating existing Layer7 rule: " . $L7DNSruleName)
        /ip firewall layer7-protocol set [find where name=$L7DNSruleName] regexp=$L7DNSruleRegexp
    } else={
        :log info ("Creating new Layer7 rule: " . $L7DNSruleName)
        /ip firewall layer7-protocol add name=$L7DNSruleName regexp=$L7DNSruleRegexp
    }


    /ip firewall nat
    add action=dst-nat chain=output dst-port=53 layer7-protocol=$L7DNSruleName protocol=udp to-addresses=$AADNSPrivateServer
    add action=dst-nat chain=dstnat dst-port=53 layer7-protocol=$L7DNSruleName protocol=udp to-addresses=$AADNSPrivateServer

    /ip route add comment=dns_redirect disabled=no dst-address=($AADNSPrivateServer."/32") gateway=$AADNSPrivateServerGW routing-table=main suppress-hw-offload=no

}

:put "### disable default route and DNS from dhcp client"
/ip dhcp-client set add-default-route=no use-peer-dns=no [find interface =ether1]
/ip dhcp-client set add-default-route=no use-peer-dns=no [find interface =ether2]
#denable default route for SSTP
/interface/sstp-client/set add-default-route=yes [find name=$AAVPNSSTPName]


:if ($AADNSCacheWatcherEnabled=1) do={ 
    :put "### setup script to to find and removed unwanted cached records"
    :do {/system script
    add dont-require-permissions=no name=filtered_dns_flush owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon \
        source="{\
        \n    :local filteredIP \"$AADNSCacheWatcherRegex\"\
        \n    :local filterdDNSCount [:len [/ip dns cache find where data~\$filteredIP]]\
        \n    :if (\$filterdDNSCount > 0) do={  \
        \n        :log error \"found\"  \
        \n        :local filteredHost [/ip dns cache get ([find where data~\$filteredIP]->0) name]\
        \n        :local filteredHostIP [/ip dns cache get ([find where data~\$filteredIP]->0) data]\
        \n        :local msg (\$filterdDNSCount.\" filtered DNS found. the first one is: \".\$filteredHost.\",\".\$filteredHostIP.\" Flushing DN\
        S\")\
        \n        :put \$msg\
        \n        :log error \$msg\
        \n        /ip dns cache flush\
        \n\
        \n        }\
        \n}"
        
    } on-error={:put "filtered_dns_flush exisit"
    /system script set owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon \
        source="{\
        \n    :local filteredIP \"$AADNSCacheWatcherRegex\"\
        \n    :local filterdDNSCount [:len [/ip dns cache find where data~\$filteredIP]]\
        \n    :if (\$filterdDNSCount > 0) do={  \
        \n        :log error \"found\"  \
        \n        :local filteredHost [/ip dns cache get ([find where data~\$filteredIP]->0) name]\
        \n        :local filteredHostIP [/ip dns cache get ([find where data~\$filteredIP]->0) data]\
        \n        :local msg (\$filterdDNSCount.\" filtered DNS found. the first one is: \".\$filteredHost.\",\".\$filteredHostIP.\" Flushing DN\
        S\")\
        \n        :put \$msg\
        \n        :log error \$msg\
        \n        /ip dns cache flush\
        \n\
        \n        }\
        \n}" [find name=filtered_dns_flush]
    }
    :do {    /system scheduler
    add interval=15s name=reset_dns_cache_filtered_ip on-event=filtered_dns_flush policy=\
        ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon
    } on-error={:put "scheduler for reset dns cache exist"}

}


}