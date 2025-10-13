# Determine VPN Tunnel Maximum MTU and OpenVPN Server Config Option to Fix

## Why would you need to do this?

Your VPN connection is up, but web sites (HTTP)  and SSH will not load/connect or are very very slow knowing that your ping and network bandwidth are good. This is a common problem with DSL (PPPoE) or other links where the MTU is less than 1500, often due to Path MTU Discovery (PMTUD) failure when the required ICMP error packets are dropped by a firewall.

* * *

## You must have a working VPN connection so that you can ping the client from the OpenVPN server

You can find the client's IP address in the OpenVPN server log. The client name is normally what you named your client config file (for example: client-thinkpad.ovpn). The client I want to test is client-thinkpad. Search for the client's IP address. I use the journalctl command to search—it'll be the 'pool return IPv4=xxx.xxx.xxx.xxx' entry.

```text
sudo journalctl -u openvpn@server.service  | grep client-thinkpad | grep 'pool returned IPv4'
Oct 09 17:57:59 mars ovpn-server[4043]: client-thinkpad/<your IP>:54988 MULTI_sva: pool returned IPv4=10.8.0.2, IPv6=(Not enabled)

```

* * *

## Test the connection with ping to find maximum packet size the VPN will support

This the example is OpenVPN over a DSL (PPoE) connection.

From the OpenVPN server, ping the client's IPv4 address, 10.8.0.2 in my case. I already set the MTU, so yours might be different. I used many different payload sizes before I found the max; here are just the two that narrowed it down. My client is connected via Starlink, which is why the ping looks high—not bad for going to space and back.

```text
ping -M do -s 1405 10.8.0.2
PING 10.8.0.2 (10.8.0.2) 1405(1433) bytes of data.
ping: local error: message too long, mtu=1432
ping: local error: message too long, mtu=1432
ping: local error: message too long, mtu=1432
ping: local error: message too long, mtu=1432
ping: local error: message too long, mtu=1432
^C
--- 10.8.0.2 ping statistics ---
5 packets transmitted, 0 received, +5 errors, 100% packet loss, time 4072ms

ping -M do -s 1404 10.8.0.2
PING 10.8.0.2 (10.8.0.2) 1404(1432) bytes of data.
1412 bytes from 10.8.0.2: icmp_seq=1 ttl=128 time=55.5 ms
1412 bytes from 10.8.0.2: icmp_seq=2 ttl=128 time=57.4 ms
1412 bytes from 10.8.0.2: icmp_seq=3 ttl=128 time=54.9 ms
1412 bytes from 10.8.0.2: icmp_seq=4 ttl=128 time=62.1 ms
1412 bytes from 10.8.0.2: icmp_seq=5 ttl=128 time=62.4 ms
1412 bytes from 10.8.0.2: icmp_seq=6 ttl=128 time=51.0 ms

--- 10.8.0.2 ping statistics ---
6 packets transmitted, 6 received, 0% packet loss, time 5008ms
rtt min/avg/max/mdev = 51.022/57.211/62.434/4.030 ms

```

* * *

## OpenVPN Overhead (UDP)

I'm using the default channel encryption `AES-256-GCM`. Look at your logs to verify and adjust accordingly

### OpenVPN Overhead (UDP, AES-256-GCM)

| Component | Size (bytes) |
| --- | --- |
| OpenVPN DATA_V2 (Header + GCM Tag) | 24  |
| UDP Header | 8   |
| Outer IPv4 Header | 20  |
| **Total OpenVPN Encapsulation Overhead** | 52  |

### DSL Overhead (PPoE)

| Component | Size (bytes) |
| --- | --- |
| Data Link/PPPoE Overhead | 8   |

### Total Overhead for the DSL Link

Total outer (OpenVPN) overhead:  
52 OpenVPN + 8 PPoE = `60 bytes`

### Analysis of the Ping Test Result

The maximum ICMP payload size from the ping test was 1404 bytes.

Calculate the maximum MTU for the DSL link:  
1404 ICMP Data + 20 IP Header + 8 ICMP Header = 1432 Maximum MTU

Since the goal is to avoid fragmentation by respecting the largest MTU on the path, so the maximum inner MTU needs to be =< 1432.

| Tested Max ICMP Data | ICMP/IP Overhead | Confirmed Max Path MTU |
| --- | --- | --- |
| 1404 bytes | +28 bytes | 1432 bytes |

This also confirms the DSL link MTU is 1492 bytes  
1432 VPN inner MTU + 52 OpenVPN + 8 PPoE = 1492 bytes

Which is a common PPoE MTU size.  
1500 Ethernet MTU - 8 PPoE overhead = 1492 bytes.

* * *

## Setting the Inner Tunnel MTU

The maximum size for the inner IP packet (the traffic inside the tunnel, which is what the tun-mtu setting controls) must be the largest size that, when fully encapsulated by OpenVPN does not exceed your outer MTU, which is 1492 for my PPoE DSL link.

The inner MTU of the tunnel based on ping tests.  
1404 from ping test +20 IP Header +8 ICMP Header = `1432` Maximum inner MTU

Set the `tun-mtu 1432` in the /etc/openvpn/server.conf config file and restart the server.

```text
sudo nano /etc/openvpn/server.conf
sudo systemctl restart openvpn.service
```

* * *

## Test the MSS clamping

**Web sites should now load.**

Verify the MTU is set to the value set by `tun-mtu` 1432 in this case.

```text
* Linux
ip a show tun0
18: tun0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1432 qdisc fq_codel state UNKNOWN group default qlen 500
    link/none 
    inet 10.8.0.1/24 scope global tun0
       valid_lft forever preferred_lft forever
    inet6 fe80::21a6:c3bf:7783:e4c8/64 scope link stable-privacy 
       valid_lft forever preferred_lft forever

* Windows 11
netsh interface ipv4 show subinterfaces

       MTU  MediaSenseState      Bytes In     Bytes Out  Interface
----------  ---------------  ------------  ------------  -------------
4294967295                1             0        112725  Loopback Pseudo-Interface 1
     65535                5             0             0  OpenVPN Wintun
      1500                1     193137021      49070504  Wi-Fi
      1500                5             0             0  Bluetooth Network Connection
      1500                5             0             0  OpenVPN TAP-Windows6
      1500                5             0             0  Local Area Connection* 1
      1432                1     107411217      20356825  OpenVPN Data Channel Offload     <------- this line
      1500                5             0             0  Local Area Connection* 2
      1500                1        255297       1201796  vEthernet (WSL)
```

Use the tcpdump command on the VPN server, and monitor the TCP MSS. The MSS option should be 1392.  
(tun-mtu=1432) - 40 (IP/TCP header) = `mss 1392`

10.8.0.2 is the VPN client and 10.10.0.204 is my Proxmox server on my lan. I am using NAT  on the OpenVPN server to access my local network, that is why the different subnets.

The MSS from the web server (10.10.0.204) may have a different MSS than listed below, which is normally 1460 (1500 Ethernet MTU minus 40 IP/TCP headers), if you haven't set it with an iptables rule. What we're interested in is what the client's (10.8.0.2) MSS sends to the server for testing. To set the MSS from the web server to the VPN, use the iptables command(s) below.

Linux and Window's kernel may derive the correct MSS from the tun interface's MTU, it is best practice to include the iptables TCPMSS rule for both directions when dealing with VPNs.

```text
sudo tcpdump -i tun0 -nl | grep mss
[sudo] password for user: 
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on tun0, link-type RAW (Raw IP), snapshot length 262144 bytes
22:29:30.600135 IP 10.8.0.2.57698 > 10.10.0.204.8006: Flags [S], seq 1352582822, win 65535, options [mss 1392,nop,wscale 8,nop,nop,sackOK], length 0
22:29:30.600173 IP 10.8.0.2.50937 > 10.10.0.204.8006: Flags [S], seq 256465994, win 65535, options [mss 1392,nop,wscale 8,nop,nop,sackOK], length 0
22:29:30.600294 IP 10.10.0.204.8006 > 10.8.0.2.57698: Flags [S.], seq 3389130376, ack 1352582823, win 64240, options [mss 1392,nop,nop,sackOK,nop,wscale 7], length 0
22:29:30.600300 IP 10.10.0.204.8006 > 10.8.0.2.50937: Flags [S.], seq 1966382350, ack 256465995, win 64240, options [mss 1392,nop,nop,sackOK,nop,wscale 7], length 0
22:30:01.980196 IP 10.10.0.204.8006 > 10.8.0.2.57698: Flags [S.], seq 3389130376, ack 1352582823, win 64240, options [mss 1392,nop,nop,sackOK,nop,wscale 7], length 0
^C

1796 packets captured
1796 packets received by filter
0 packets dropped by kernel

```

* * *

## iptables Configuration

iptables rule to set MSS clamping due to VPN tunnel overheaed and or links with a MTU less than 1500 bytes

### Mangle table: Clamp MSS for VPN traffic

```text
# replace tun0 with your interface name of your tunnnel.
iptables -t mangle -A POSTROUTING -p tcp -o tun0 --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1392
```

### Analysis of iptables Rules

[Click here for a detiled analysis of iptables of the rule.](https://github.com/wfahren/OpenVPN/blob/main/iptable_rule_detail/iptable_rules_for_OpenVPN_server.md)

## Show rule

Mangle table - MSS Clamping

```text
sudo iptables -L -n -t mangle -v

Chain PREROUTING (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain INPUT (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain FORWARD (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain OUTPUT (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain POSTROUTING (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         
 2459  128K TCPMSS     6    --  *      tun0    0.0.0.0/0            0.0.0.0/0            tcp flags:0x06/0x02 TCPMSS set 1392
```
