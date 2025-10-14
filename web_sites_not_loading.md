# Determine VPN Tunnel Maximum MTU and OpenVPN Server Config Option to Fix

## Why would you need to do this?

Your VPN connection is up, but web sites (HTTP) and SSH will not load/connect or are very very slow knowing that your ping and network bandwidth are good, this is know as `black-holing`. This is a common problem with PPPoE or other links where the MTU is less than 1500, often due to Path MTU Discovery (PMTUD) failure when the required ICMP error packets are dropped by a firewall.

* * *

## Overhead for OpenVPN over a PPPoE Link

The standard PPoE MTU is 1492, which is the maximum packet size you can transmit without fragmentation.

OpenVPN is configured using `proto udp4` and `data-ciphers AES-256-GCM` the default directives.

### TCP Segment

- **Total Overhead:**
  - Outer IP/UDP (28) + OpenVPN (32) + Inner IP/TCP (40) = **100 bytes**
- **Maximum payload:**

  - PPPoE MTU (1492) - overhead (100) = **1392 bytes**

| IP/UDP  <br>28 Bytes | OpenVPN Overhead  <br>32 Bytes | IP/TCP  <br>40 Bytes | Payload  <br>1392 Bytes |
| :---: | :---: | :---: | :---: |

### UDP Segment

- **Total Overhead:**

  - IP/UDP (28) + OpenVPN (32) + Inner IP/UDP (28) = **60 bytes**
- **Maximum payload:**

  - PPPoE MTU (1492) - overhead (60) = **1404 bytes**

| IP/UDP  <br>28 Bytes | OpenVPN Overhead  <br>32 Bytes | IP/UDP  <br>28 Bytes | Payload  <br>1404 Bytes |
| :---: | :---: | :---: | :---: |

## Test the Link

### Find the IP address of the client (if you don't know it)

You can find the client's IP address in the OpenVPN server log. The client name is normally what you named your client config file (for example: client-thinkpad.ovpn). The client I want to test is client-thinkpad. Search for the client's IP address. I use the journalctl command to search—it'll be the 'pool return IPv4=xxx.xxx.xxx.xxx' entry.

```text
sudo journalctl -u openvpn@server.service  | grep client-thinkpad | grep 'pool returned IPv4'
Oct 09 17:57:59 mars ovpn-server[4043]: client-thinkpad/<your IP>:54988 MULTI_sva: pool returned IPv4=10.8.0.2, IPv6=(Not enabled)

```

### Use ping to find maximum payload size

From the OpenVPN server, ping the client. From the above we expect 1404 will pass, since ping is a UDP Segment.

```text
ping -M do -s 1405 10.8.0.2
PING 10.8.0.2 (10.8.0.2) 1405(1433) bytes of data.
ping: local error: message too long
ping: local error: message too long
ping: local error: message too long
ping: local error: message too long
ping: local error: message too long
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

The maximum payload size was 1404 bytes. This confirms the links MTU of 1492

1404 ICMP Data + 20 IP Header + 8 IP/UDP Header = 1432 Maximum MTU

* * *

## Configure OpenVPN

### Setting the Inner Tunnel MTU

The maximum size for the inner IP packet (the traffic inside the tunnel, which is what the tun-mtu setting controls) must be the largest size that, when fully encapsulated by OpenVPN does not exceed your outer MTU, which is 1492 for PPoE.

1404 from ping test +20 IP Header +8 ICMP Header = `1432` Maximum inner MTU

**Add `tun-mtu 1432` directive to the /etc/openvpn/server.conf config file and restart the server.**

```text
sudo nano /etc/openvpn/server.conf
sudo systemctl restart openvpn.service
```

## iptables Configuration

### Mangle table: Clamp MSS for VPN traffic

```text
# replace tun0 with your interface name of your tunnnel.
iptables -t mangle -A POSTROUTING -p tcp -o tun0 --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1392
```

### Analysis of iptables Rules

[Click here for a detailed analysis of iptables of the rule.](https://github.com/wfahren/OpenVPN/blob/main/iptable_rule_detail/iptable_rules_for_OpenVPN_server.md)

* * *

## Test

**Web sites should now load.**

Verify the MTU is set to the value set by `tun-mtu` 1432.

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

Use tcpdump and look for the `MSS option`, it should be 1392 in both directions.

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
