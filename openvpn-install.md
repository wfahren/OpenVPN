# Install OpenVPN and Easy-RSA

## Install and setup Easy-RSA

Install required packages and create a symlink for the `easyrsa` script

```text
sudo apt update && sudo apt install easy-rsa openvpn -y
mkdir -p ~/easy-rsa
ln -s /usr/share/easy-rsa/easyrsa ~/easy-rsa/easyrsa
cd ~/easy-rsa
```

* * *

### Creating a PKI for OpenVPN

Create and edit the `vars` file using nano or your preferred text editor. The vars file is used when you create the server it will ensure that your private keys and certificate requests are configured to use modern Elliptic Curve Cryptography (ECC) to generate keys and secure signatures for your clients and OpenVPN server.

```text
nano ~/easy-rsa/vars
```

Once the file is opened, paste in the following lines:

```text
set_var EASYRSA_ALGO "ec"
set_var EASYRSA_DIGEST "sha512"
set_var EASYRSA_CA_EXPIRE 3650  #Set the CA to expire in 10 years
set_var EASYRSA_CERT_EXPIRE 3650 #Set the certificates to expire in 10 years

```

Initialize the PKI inside the easy-rsa directory:

```text
./easyrsa init-pki
```

Show the directory structure for Easy-RSA.

```text
./easyrsa |grep -A4 DIRECTORY
DIRECTORY STATUS (commands would take effect on these locations)
     EASYRSA: /home/user/easy-rsa
         PKI: /home/user/easy-rsa/pki
   vars-file: /home/user/easy-rsa/vars
   CA status: CA has not been built
```

* * *

## Server Configuration

* * *

Build ca.crt and cert/key for server. We are using `openvpn-server` for the server name.

```text
./easyrsa build-ca nopass
./easyrsa build-server-full openvpn-server nopass
```

* * *

### Create the tls-crypt key

We are using the `tls-crypt ta.key` server option, to not only authenticate, but also encrypt the TLS control channel.

To generate the `tls-crypt` pre-shared key, run the following command in the `~/easy-rsa` directory to generate the key. The openvpn command is not accessible for non-root users; sudo is required to create the key.

```text
sudo openvpn --genkey secret ta.key
```

**note:** You will only do this once. The same `ta.key` is used by the server and all clients.

Since we created the ta.key using sudo, we need to change the ownership from root to your current user. We will later use this file when we create the client .ovpn file as non-root.

```text
sudo chown $USER: ta.key
```

* * *

### Copy the Cert and Keys for the Server

Copy the ca.crt and openvpn-server cert/key to the /etc/openvpn/server/ directory.

```text
sudo cp ta.key /etc/openvpn/server 
sudo cp ~/easy-rsa/pki/ca.crt /etc/openvpn/server
sudo cp ~/easy-rsa/pki/private/openvpn-server.key /etc/openvpn/server
sudo cp ~/easy-rsa/pki/issued/openvpn-server.crt /etc/openvpn/server
```

**Certificate and key generation is complete.**

* * *

### Configuring OpenVPN

Create the  `server.conf`  and paste the below server options into the /etc/openvpn/server.conf.

```text
# Backup any existing /etc/openvpn/server.conf, if one exists. 
sudo mv /etc/openvpn/server.conf /etc/openvpn/server.conf-$(date +%Y%m%d-%H%M%S)
sudo nano /etc/openvpn/server.conf
```

Insert options below into the /etc/openvpn/server.conf

```text
port 1194
proto udp4
dev tun
ca /etc/openvpn/server/ca.crt
cert /etc/openvpn/server/openvpn-server.crt
key /etc/openvpn/server/openvpn-server.key
tls-crypt /etc/openvpn/server/ta.key
dh none
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist /var/log/openvpn/ipp.txt
# Change this to match your local LAN network subnet.
push "route 10.10.0.0 255.255.255.0"
# If you want all traffic to route through the VPN tunnel, otherwise comment out with ;
# not using means only traffic to your local LAN is routed through the VPN
push "redirect-gateway def1 bypass-dhcp"
# Change this to your DNS IP
push "dhcp-option DNS 10.10.0.1"
push "dhcp-option DOMAIN lan"
topology subnet
keepalive 10 120
persist-key
persist-tun
status /var/log/openvpn/openvpn-status.log
verb 3
explicit-exit-notify 1
# If web sites are NOT loading once the VPN is up, remove the ; and adjust tun-mtu for your needs  
;tun-mtu 1432
```

### Explanation of important server options

| Server Option | Value |     |
| --- | --- | --- |
| push route | 10.10.0.0 255.255.255.0 | [more information](https://github.com/wfahren/OpenVPN/blob/main/server-options/server_option_push_route.md) |
| push dhcp-option DNS | 10.10.0.1 | [more information](https://github.com/wfahren/OpenVPN/blob/main/server-options/server_option_dhcp-option_DNS.md) |
| push dhcp-option DOMAIN | lan | [more information](https://github.com/wfahren/OpenVPN/blob/main/server-options/server_option_dhcp-option_DOMAIN.md) |
| redirect-gateway | redirect-gateway def1 bypass-dhcp | [more information](https://github.com/wfahren/OpenVPN/blob/main/server-options/server_option_redirect-gateway.md) |
| tun-mtu | 1432 | [more information](https://github.com/wfahren/OpenVPN/blob/main/web_sites_not_loading.md) |

### Restart the OpenVPN Server

```text
sudo systemctl restart openvpn.service
```

#### Check for any Errors

```text
sudo journalctl -u openvpn@server.service -xe
```

## NAT Setup Using iptables

This server configuration is using NAT to access the local LAN. So we need to set some iptable rules to allow the traffic.

## IP Forwarding and iptables Configuration

Use as a guide if you are using NAT from the VPN server to the local network. adjust your interface names accordingly.

### Enable IP forwarding

```text
sysctl -w net.ipv4.ip_forward=1
# Making the setting permanent by editing /etc/sysctl.conf and adding net.ipv4.ip_forward = 1
sudo nano /etc/sysctl.conf 
sudo sysctl -p
```

## iptables Rules

These five iptables rules configure the OpenVPN server to function as a router, enabling traffic to pass from the VPN subnet (10.8.0.0/24) to the local network (10.10.0.0/24) and the internet. This allows VPN clients to directly access local resources and to use the local network's gateway (DSL router) for internet access.

To allow Internet routing the OpenVPN server configuration file, located at `/etc/openvpn/server.conf`, must include the directive:`push "redirect-gateway def1 bypass-dhcp"`

### NAT table: Masquerade VPN client traffic

```text
# replace enp6s18 with your interface name that connects to your lan.
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o enp6s18 -j MASQUERADE
```

### Mangle table: Clamp MSS for VPN traffic

See this [guide](https://github.com/wfahren/OpenVPN/blob/main/web_sites_not_loading.md) on how to determine the MTU. Normally only required if the connection is a link with MTU >1500 bytes, DSL for example. Having said that it is good practice to set when dealing with VPN's

```text
# replace tun0 with your interface name of your tunnnel.
iptables -t mangle -A POSTROUTING -p tcp -o tun0 --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1392
```

### Filter table: Allow established/related traffic

```text
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
```

### Filter table: Allow VPN clients to access internal network

```text
iptables -A FORWARD -s 10.8.0.0/24 -d 10.10.0.0/24 -j ACCEPT
```

### Analysis of iptables Rules

[Click here for a detiled analysis of iptables of the rules.](https://github.com/wfahren/OpenVPN/blob/main/iptable_rule_detail/iptable_rules_for_OpenVPN_server.md)

* * *

### Verify rules

NAT table

```text
sudo iptables -L -n -t nat -v
Chain PREROUTING (policy ACCEPT 64641 packets, 7877K bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain INPUT (policy ACCEPT 1500 packets, 203K bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain OUTPUT (policy ACCEPT 473 packets, 236K bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain POSTROUTING (policy ACCEPT 475 packets, 237K bytes)
 pkts bytes target     prot opt in     out     source               destination         
 9340  600K MASQUERADE  0    --  *      enp6s18  10.8.0.0/24          0.0.0.0/0           
```

Mangle table

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

Filter table

```text
sudo iptables -L -n -t filter -v
Chain INPUT (policy ACCEPT 208K packets, 63M bytes)
 pkts bytes target     prot opt in     out     source               destination         
82373   15M ACCEPT     0    --  *      *       0.0.0.0/0            0.0.0.0/0            state RELATED,ESTABLISHED

Chain FORWARD (policy ACCEPT 206K packets, 138M bytes)
 pkts bytes target     prot opt in     out     source               destination         
64997   42M
ACCEPT     0    --  *      *       0.0.0.0/0            0.0.0.0/0            state RELATED,ESTABLISHED
 4420  293K ACCEPT     0    --  tun0   *       10.8.0.0/24          10.10.0.0/24        

Chain OUTPUT (policy ACCEPT 356K packets, 243M bytes)
 pkts bytes target     prot opt in     out     source               destination    
```

* * *

## Client configuration

* * *

### Create the Client Certificate and Key

```text
./easyrsa build-client-full client-thinkpad nopass
```

### Create .ovpn File for your Client

I have created a BASH script `make-client-ovpn.sh` to automate this process.

This script generates an all-in-one OpenVPN client configuration file (.ovpn). The script will make an inline file that includes the CA certificate, client certificate, client key, TLS-crypt key, and base config options.

Download and place in your `~/easy-rsa` directory.

```text
cd ~/easy-rsa
wget https://raw.githubusercontent.com/wfahren/OpenVPN/refs/heads/main/make-client-ovpn.sh
chmod +x make-client-ovpn.sh
```

* * *

### Create file with client option

Create client-base.conf file that will have the OpenVPN client options needed for a client to connect.

```text
cd ~/easy-rsa
nano client-base.conf
```

Paste the below client options into the file.

```text
# Start client options
client
dev tun
proto udp4
remote yourOpenvpnServer.com 1194 #  can be IP or domainname
resolv-retry infinite
nobind
key-direction 1
persist-key
persist-tun
remote-cert-tls server
verb 3
# End Client option
```

* * *

### make-client-ovpn usage

The make-client-ovpn.sh script takes only one argument: the client name (e.g., client-thinkpad).

```text
cd ~/easy-rsa
./make-client-config client-thinkpad
Validating required files for client-thinkpad...
Generating OpenVPN configuration for client: client-thinkpad...
SUCCESS: Configuration saved to /home/user/easy-rsa/client-ovpn-files/client-thinkpad.ovpn
```

The script will create a .ovpn file in the ~/easy-rsa/client-ovpn-files directory that you will use on the client(s).

The script has variables that can be changed if you want to store the .ovpn file somewhere else, or your certificates and key are in a different directory other than `/easy-rsa`.

```text
EASY_RSA_DIR="$HOME/easy-rsa"                    # Location of easy-rsa directory
CLIENT_CONFIG_DIR="$HOME/easy-rsa"               # Location of client-ovpn-files directory
OUTPUT_DIR="$HOME/easy-rsa/client-ovpn-files"    # Location for client .ovpn files
BASE_CONFIG="$HOME/easy-rsa/client-base.conf"    # Location of client OpenVPN base config
```
