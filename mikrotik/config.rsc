# 2024-11-19 21:24:29 by RouterOS 7.14.1
# software id = GNVB-4V9V
#
# model = RB5009UG+S+
# serial number = HFD095R4B6E
/interface bridge
add admin-mac=78:9A:18:BD:BF:20 auto-mac=no comment=defconf name=bridge port-cost-mode=short
add comment="bridges some ports to \"WAN\" (dtcnet/home LAN) on ether1" name=dtcnet_bridge
add comment="Bridge for BF3 network behind Protectli" name=labnet_bridge
/interface ethernet
set [ find default-name=ether1 ] comment="dtcnet (eero)"
set [ find default-name=ether2 ] comment="Laptop docking station"
set [ find default-name=ether3 ] comment="RPi5 (rpi.local)"
set [ find default-name=ether4 ] comment=Protectli
set [ find default-name=ether5 ] comment=NUC
set [ find default-name=ether6 ] comment="RPi4 (bastion.local)"
set [ find default-name=ether7 ] comment="Lutron hub (bridged to dtcnet)"
set [ find default-name=ether8 ] comment="Lauren's office (bridged to dtcnet)"
/interface vlan
add comment="Bridges dpu-host to dtcnet" interface=ether5 name=vlan192 vlan-id=192
/interface list
add comment=defconf name=WAN
add comment=defconf name=LAN
/interface wireless security-profiles
set [ find default=yes ] supplicant-identity=MikroTik
/ip dhcp-server
add interface=labnet_bridge name=labnet
/ip pool
add name=dhcp ranges=10.42.42.2-10.42.42.254
/ip dhcp-server
add address-pool=dhcp interface=bridge lease-time=10m name=defconf
/interface bridge port
add bridge=bridge comment=defconf interface=ether2 internal-path-cost=10 path-cost=10
add bridge=dtcnet_bridge comment=defconf interface=ether3 internal-path-cost=10 path-cost=10
add bridge=bridge interface=ether6 internal-path-cost=10 path-cost=10
add bridge=dtcnet_bridge interface=ether7 internal-path-cost=10 path-cost=10
add bridge=dtcnet_bridge interface=ether8 internal-path-cost=10 path-cost=10
add bridge=bridge comment=defconf interface=sfp-sfpplus1 internal-path-cost=10 path-cost=10
add bridge=labnet_bridge interface=ether4
add bridge=dtcnet_bridge interface=ether1
add bridge=bridge interface=ether5
add bridge=dtcnet_bridge comment="Bridges dpu-host to dtcnet" interface=vlan192
/ip firewall connection tracking
set udp-timeout=10s
/ip neighbor discovery-settings
set discover-interface-list=LAN
/interface list member
add comment=defconf interface=bridge list=LAN
add comment=defconf interface=dtcnet_bridge list=WAN
/ip address
add address=10.42.42.1/16 comment=defconf interface=bridge network=10.42.0.0
add address=10.255.1.2/24 interface=labnet_bridge network=10.255.1.0
/ip dhcp-client
add interface=dtcnet_bridge
/ip dhcp-server lease
add address=10.42.42.10 client-id=work-laptop comment="Work MBP" mac-address=AC:1A:3D:34:5E:F0 server=defconf
add address=10.255.1.1 comment="dpu-dev Protectli" mac-address=00:E0:67:30:D6:DE server=labnet
add address=10.42.42.11 client-id=personal-laptop comment="Personal MBP" mac-address=AC:1A:3D:34:5E:F0 server=defconf
add address=10.42.42.42 client-id=1:e4:5f:1:ef:d7:10 comment="bastion RPi" mac-address=E4:5F:01:EF:D7:10 server=defconf
add address=10.42.42.2 comment="NUC br0" mac-address=92:B9:36:6D:7F:97 server=defconf
/ip dhcp-server network
add address=10.42.0.0/16 comment=defconf dns-server=10.42.42.1 gateway=10.42.42.1 netmask=16
add address=10.255.1.0/30 comment="Link to Protectli" dns-server=8.8.8.8,8.8.4.4 gateway=10.255.1.2
/ip dns
set allow-remote-requests=yes servers=8.8.8.8,8.8.4.4
/ip dns static
add address=10.42.42.1 comment=defconf name=router.lan
add address=192.168.5.238 name=rpi
add address=10.255.0.1 name=dpu-dev
add address=10.42.42.2 name=dpu-host
add address=10.255.2.3 name=dpu
/ip firewall filter
add action=accept chain=input comment="defconf: accept established,related,untracked" connection-state=established,related,untracked
add action=drop chain=input comment="defconf: drop invalid" connection-state=invalid log=yes log-prefix="[invalidinput]"
add action=accept chain=input comment="defconf: accept ICMP" protocol=icmp
add action=accept chain=input comment="defconf: accept to local loopback (for CAPsMAN)" dst-address=127.0.0.1
add action=accept chain=input comment="Allow SNMP from RPi for monitoring" dst-port=161 protocol=udp src-address=192.168.5.238
add action=drop chain=input comment="defconf: drop all not coming from LAN" in-interface-list=!LAN
add action=accept chain=forward comment="defconf: accept in ipsec policy" ipsec-policy=in,ipsec
add action=accept chain=forward comment="defconf: accept out ipsec policy" ipsec-policy=out,ipsec
add action=fasttrack-connection chain=forward comment="defconf: fasttrack" connection-state=established,related hw-offload=yes
add action=accept chain=forward comment="defconf: accept established,related, untracked" connection-state=established,related,untracked
add action=drop chain=forward comment="defconf: drop invalid" connection-state=invalid log=yes log-prefix="[invalid]"
add action=drop chain=forward comment="defconf: drop all from WAN not DSTNATed" connection-nat-state=!dstnat connection-state=new in-interface-list=WAN
/ip firewall nat
add action=masquerade chain=srcnat comment="defconf: masquerade" ipsec-policy=out,none out-interface-list=WAN
add action=dst-nat chain=dstnat comment="allow SSH to lab bastion (but only from RPi)" dst-port=4242 in-interface=dtcnet_bridge protocol=tcp src-address=192.168.5.238 to-addresses=10.42.42.42 to-ports=22
/ip firewall raw
add action=notrack chain=prerouting comment="Disable conntrack for traffic between labnet and k8s subnet" dst-address=10.96.0.0/12 src-address=10.42.0.0/16
add action=notrack chain=prerouting comment="Disable conntrack for traffic between labnet and MetalLB subnet" dst-address=172.16.42.0/24 src-address=10.42.0.0/16
/ip route
add disabled=no distance=1 dst-address=10.255.0.0/16 gateway=10.255.1.1 pref-src="" routing-table=main suppress-hw-offload=no
add comment="Route for MetalLB" disabled=no distance=1 dst-address=172.16.42.0/24 gateway=10.42.42.100 pref-src="" routing-table=main suppress-hw-offload=no
add comment="Route for k8s cluster" disabled=no distance=1 dst-address=10.96.0.0/12 gateway=10.42.42.100 pref-src="" routing-table=main suppress-hw-offload=no
/ipv6 firewall address-list
add address=::/128 comment="defconf: unspecified address" list=bad_ipv6
add address=::1/128 comment="defconf: lo" list=bad_ipv6
add address=fec0::/10 comment="defconf: site-local" list=bad_ipv6
add address=::ffff:0.0.0.0/96 comment="defconf: ipv4-mapped" list=bad_ipv6
add address=::/96 comment="defconf: ipv4 compat" list=bad_ipv6
add address=100::/64 comment="defconf: discard only " list=bad_ipv6
add address=2001:db8::/32 comment="defconf: documentation" list=bad_ipv6
add address=2001:10::/28 comment="defconf: ORCHID" list=bad_ipv6
add address=3ffe::/16 comment="defconf: 6bone" list=bad_ipv6
/ipv6 firewall filter
add action=accept chain=input comment="defconf: accept established,related,untracked" connection-state=established,related,untracked
add action=drop chain=input comment="defconf: drop invalid" connection-state=invalid
add action=accept chain=input comment="defconf: accept ICMPv6" protocol=icmpv6
add action=accept chain=input comment="defconf: accept UDP traceroute" port=33434-33534 protocol=udp
add action=accept chain=input comment="defconf: accept DHCPv6-Client prefix delegation." dst-port=546 protocol=udp src-address=fe80::/10
add action=accept chain=input comment="defconf: accept IKE" dst-port=500,4500 protocol=udp
add action=accept chain=input comment="defconf: accept ipsec AH" protocol=ipsec-ah
add action=accept chain=input comment="defconf: accept ipsec ESP" protocol=ipsec-esp
add action=accept chain=input comment="defconf: accept all that matches ipsec policy" ipsec-policy=in,ipsec
add action=drop chain=input comment="defconf: drop everything else not coming from LAN" in-interface-list=!LAN
add action=accept chain=forward comment="defconf: accept established,related,untracked" connection-state=established,related,untracked
add action=drop chain=forward comment="defconf: drop invalid" connection-state=invalid
add action=drop chain=forward comment="defconf: drop packets with bad src ipv6" src-address-list=bad_ipv6
add action=drop chain=forward comment="defconf: drop packets with bad dst ipv6" dst-address-list=bad_ipv6
add action=drop chain=forward comment="defconf: rfc4890 drop hop-limit=1" hop-limit=equal:1 protocol=icmpv6
add action=accept chain=forward comment="defconf: accept ICMPv6" protocol=icmpv6
add action=accept chain=forward comment="defconf: accept HIP" protocol=139
add action=accept chain=forward comment="defconf: accept IKE" dst-port=500,4500 protocol=udp
add action=accept chain=forward comment="defconf: accept ipsec AH" protocol=ipsec-ah
add action=accept chain=forward comment="defconf: accept ipsec ESP" protocol=ipsec-esp
add action=accept chain=forward comment="defconf: accept all that matches ipsec policy" ipsec-policy=in,ipsec
add action=drop chain=forward comment="defconf: drop everything else not coming from LAN" in-interface-list=!LAN
/snmp
set enabled=yes
/system clock
set time-zone-name=America/New_York
/system note
set show-at-login=no
/tool mac-server
set allowed-interface-list=LAN
/tool mac-server mac-winbox
set allowed-interface-list=LAN
