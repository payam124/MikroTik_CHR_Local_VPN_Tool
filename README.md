# MikroTik_CHR_Local_VPN_Tool
This helps you to setup a CHR on your windows machine and establish VPNs and apply the required routings

# Local CHR MikroTik to handle VPN and traffic Split

## Summary

This document aims to guide you through the process of setting up a CHR on the local Windows machine over Hyper-V and using that as the gateway for the machine itself. So the traffic of the machine will go to the CHR, and the CHR‌ will manage the access to the local and remote network(s).

One of the ideas is to allow Visual Studio Pro residing on a machine within a corporate network, which can only access outside through VPN, and also it needs to work with a locally hosted GitLab and at the same time have access to CoPilot. Visual Studio 2022 dos not support something like FoxyProxy to access different destinations using different proxies. This solution bring such a feature through Networking and PBR (Policy Based Routing)

## pre-requisites

- Update your Visual Studio 2022
- Check your BIOS, and if you have the VTX option, please turn it on
- Enable Hyper-V on your Windows machine (it should be possible to use VMware and VirtualBox, but I won’t go that direction in this document)
    - run→ appwiz.cpl
    - references:
        - https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/get-started/install-hyper-v?pivots=windows
        - https://techcommunity.microsoft.com/blog/educatordeveloperblog/step-by-step-enabling-hyper-v-for-use-on-windows-11/3745905
        - PowerShell as admin
            
            ```powershell
            Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
            ```
            
        - Command Line
            
            ```powershell
            DISM /Online /Enable-Feature /All /FeatureName:Microsoft-Hyper-V
            ```
            
- Download VHDX image of latest CHR (CloudHosted Router) from Mikrotik Website:
    - https://mikrotik.com/download
- Download latest Winbox from Mikrotik website
    - https://mikrotik.com/download (beta version 4 is ok)
- Create new credentials on MikroTik.com
    - https://mikrotik.com/client/
- Download AnyDesk (if you need support from a [MikroTik certified Consultant](https://mikrotik.com/consultants/northamerica/canada)
    - https://anydesk.com/en

## How to set up Hyper-V Networking

- Create 2 External network Switches in HyperV, one with your WiFi one with your Ethernet
    - GUI→ Add, External, Select Network Adapter which is connected to the LAN (Ethernet is preferred, but WiFi also works), Allow Management OS to use it.
        
        <aside>
        🔥
        
        Speed test before starting, take a note of you upload/download speed
        
        </aside>
        
    - Command
        
        ```powershell
        # Find Adaptor name
        Get-NetAdapter
        # Add Switch
        New-VMSwitch -Name "MyExternalSwitch" -NetAdapterName "Ethernet" -AllowManagementOS $true
        
        # verify
        Get-VMSwitch
        
        ```
        
    - More Complete Script
        
        ```powershell
        # Run powershell in a way that can run scripts
        #run cmd ad an admin
        %SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Unrestricted
        ```
        
        ```powershell
        # Get physical adapters (exclude virtual, loopback, Bluetooth)
        $adapters = @(Get-NetAdapter | Where-Object {
            $_.HardwareInterface -eq $true -and
            $_.InterfaceDescription -notmatch "Hyper-V|Virtual|Loopback|Bluetooth"
        })
        
        if ($adapters.Count -eq 0) {
            Write-Host "No suitable physical network adapters found." -ForegroundColor Red
            exit
        }
        
        # Display adapters
        Write-Host "Available Physical Network Adapters:" -ForegroundColor Cyan
        $i = 0
        $adapters | ForEach-Object {
            Write-Host "[$i] $($_.Name) - $($_.InterfaceDescription)"
            $i++
        }
        
        # User selection
        $selection = Read-Host "Enter the number of the adapter you want to use"
        [int]$selectionIndex = -1
        if (-not [int]::TryParse($selection, [ref]$selectionIndex)) {
            Write-Host "Invalid input. Please enter a number." -ForegroundColor Red
            exit
        }
        if ($selectionIndex -lt 0 -or $selectionIndex -ge $adapters.Count) {
            Write-Host "Selection out of range." -ForegroundColor Red
            exit
        }
        
        $selectedAdapter = $adapters[$selectionIndex]
        $adapterName = $selectedAdapter.Name
        $adapterDescription = $selectedAdapter.InterfaceDescription
        $switchName = "ExternalSwitch_$adapterName"
        
        # Check if any switch is already bound to this adapter
        $existingSwitch = Get-VMSwitch | Where-Object {
            $_.NetAdapterInterfaceDescription -eq $adapterDescription
        }
        
        if ($existingSwitch) {
            if ($existingSwitch.Name -ne $switchName) {
                Write-Host ""
                Write-Host "A virtual switch is already bound to '$adapterName':" -ForegroundColor Yellow
                Write-Host "  - Existing switch name: $($existingSwitch.Name)"
                Write-Host "  - Type: $($existingSwitch.SwitchType)"
                Write-Host ""
                Write-Host "If you want to rename it to match this script's naming convention, use:"
                Write-Host "Rename-VMSwitch -Name `"$($existingSwitch.Name)`" -NewName `"$switchName`""
                exit
            } else {
                Write-Host ""
                Write-Host "A matching virtual switch '$switchName' is already present."
                exit
            }
        }
        
        # No existing switch found for this adapter – create one
        Write-Host ""
        Write-Host "Creating external switch '$switchName'..."
        New-VMSwitch -Name $switchName -NetAdapterName $adapterName -AllowManagementOS $true
        Write-Host "Switch '$switchName' created successfully."
        
        ```
        
- Check Speed Connectivity as it may have decreased. reboot, or change MTU, ..
    - reboot
- Create an Internal network switch to handle the route from Windows to CHR
    - IP: 192.168.190.2/24, Gateway 192.168.190.1 with metric of 10, set DNS‌ to 192.168.190.1
    - GUI→Hypre-v Manager→Virtual Switch Manager → Add → Internal Switch
    - CLI
        
        ```powershell
        New-VMSwitch -Name "Swtich_CHR_VPN" -SwitchType Internal
        
        ```
        
    - Full Script
        
        ```powershell
        $switchName = "Swtich_CHR_VPN"
        $ipAddress = "192.168.190.2"
        $prefixLength = 24
        $gateway = "192.168.190.1"
        $dns = "192.168.190.1"
        
        # Check if the internal switch exists
        $switch = Get-VMSwitch -Name $switchName -ErrorAction SilentlyContinue
        
        if (-not $switch) {
            Write-Host "Creating internal switch: $switchName" -ForegroundColor Cyan
            New-VMSwitch -Name $switchName -SwitchType Internal
        } else {
            Write-Host "Switch '$switchName' already exists." -ForegroundColor Yellow
        }
        
        # Wait a moment for the virtual adapter to appear
        Start-Sleep -Seconds 2
        
        # Get the host-side virtual adapter connected to the internal switch
        $adapter = Get-NetAdapter | Where-Object {
            $_.InterfaceDescription -like "*Hyper-V*" -and
            $_.Name -like "*$switchName*"
        }
        
        if (-not $adapter) {
            Write-Host "Unable to find virtual adapter for switch '$switchName'." -ForegroundColor Red
            exit
        }
        
        $adapterName = $adapter.Name
        Write-Host "Configuring adapter: $adapterName" -ForegroundColor Cyan
        
        # Remove existing IPs (if any)
        Get-NetIPAddress -InterfaceAlias $adapterName -ErrorAction SilentlyContinue | Remove-NetIPAddress -Confirm:$false
        
        # Assign static IP
        New-NetIPAddress -InterfaceAlias $adapterName -IPAddress $ipAddress -PrefixLength $prefixLength -DefaultGateway $gateway -AddressFamily IPv4
        
        # Set DNS
        Set-DnsClientServerAddress -InterfaceAlias $adapterName -ServerAddresses $dns
        
        # Set gateway metric
        Set-NetIPInterface -InterfaceAlias $adapterName -AddressFamily IPv4 -InterfaceMetric 10
        
        Write-Host "Configuration completed for adapter '$adapterName'." -ForegroundColor Green
        
        ```
        

## How to set up CHR on Hyper-V

- 

```powershell
Name CHR_VPN01
gen 1
memory 256MB
disk
2x (or 3x) network interface
- Interface 1, ExternalSwitch_Wi-Fi
- interface 2, ExternalSwitch_Ethernet
- interadce 3, Swtich_CHR_VPN

```

## Configure CHR

- download files \d\d-\w+\.rsc
- edit the parameters inside `00-settings.rsc`
- option 1, copy all the files to mikrorik and start importing them
- option 2, open the files in your system and copy pate them in order to the terminal of your CHR

## Overall structure of the setup

- ether1 and ether2 are connected and bridged to your local network interfaces (i.e. Wifi and Ethernet)
- ether3 is the private link between CHR and your system
- Your system will not need IP on its physical interfaces, although those interfaces will be used as a bridge for the CHR
- Your traffic will be set to CHR
- On CHR, there are 2 VPNS
    - V_VPN_SSTP, This is your [corporate] VPN server, which provides Internet access to you
    - V_VPN_OVPN, This is your corporate private VPN, which allows you to have access to sensitive endpoints
- Your VPN servers are accessible over ether1 or ether2 (generally one of them is up, but if both, ether1 will be used)
- You have some destination IPs that have to go through V_VPN_OVPN
- You have some destination IPs that have to go through ether1
- The rest of your traffic will go through V_VPN_SSTP
- The CHR plays the role of DNS servers for the local PC, so in case of domain-based routing, DNS records would be consistent (use IP of the CHR as the DNS server of your PC)