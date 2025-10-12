# OpenVPN server option redirect-gateway

The OpenVPN server option `redirect-gateway def1 bypass-dhcp` is a directive, typically added to the server configuration file using the `push` command, that forces **all client network traffic** (including general web browsing) to be routed through the VPN tunnel.

This is a common configuration for ensuring a client's internet activity is secured by the VPN.

Here is a breakdown of each part:

- **`redirect-gateway`**:
  
  - This is the core command that tells the client to **replace its default network gateway** with the OpenVPN server's tunnel address.
  - Normally, a client's default gateway directs all non-local traffic to their local router (e.g., their home Wi-Fi device) to reach the internet. By redirecting the gateway, all internet-bound traffic is instead sent to the VPN server through the tunnel.

- **`def1`**:

  - This flag modifies *how* the default gateway is overridden.

  - Instead of simply deleting the old default route (`0.0.0.0/0`) and replacing it with a single new one pointing to the VPN server, `def1` uses **two more specific routes**: `0.0.0.0/1` and `128.0.0.0/1`.

  - These two routes collectively cover the entire IPv4 address space (`0.0.0.0/0`) but, being more specific, they **override** the original default route while still allowing it to exist. This method is often more robust and avoids potential routing issues.

- **`bypass-dhcp`**:

  - This flag instructs the client to add a specific route to its **local DHCP server** (if it's not already local to the client's network interface) that **bypasses the VPN tunnel**.

  - This is crucial because the client needs to maintain a connection to its local DHCP server to periodically renew its local IP address lease. Without this flag, the `redirect-gateway` rule might trap DHCP traffic, preventing the client from reaching its local DHCP server and potentially causing it to lose its local IP address or network connectivity.

In short, `redirect-gateway def1 bypass-dhcp` is the standard OpenVPN configuration to achieve a **full tunnel** (all traffic through the VPN) while ensuring the client can still communicate with its **local DHCP server** to maintain local network operations.
