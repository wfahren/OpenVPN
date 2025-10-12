# The OpenVPN server option dhcp-option DNS

```text
push "dhcp-option DNS 10.10.0.1"
```

## Explanation of `push "dhcp-option DNS 10.10.0.1"`

This configuration directive is typically found in the **OpenVPN server's configuration file**. Its purpose is to **instruct the OpenVPN server to send specific network configuration details** to the connecting clients.

-----

## Components

| Part | Meaning |
| :--- | :--- |
| **`push`** | This command tells the server to **"push"** the enclosed configuration string to the client. This is how the server dynamically configures the client's network settings. |
| **`"dhcp-option DNS ..."`** | This is the specific directive being pushed. It tells the client's operating system (or the OpenVPN client software) to **set the DNS server** that will be used while the VPN connection is active. |
| **`10.10.0.1`** | This is the **IP address** of the DNS server that the client should use. This IP address is usually an internal IP address of a device on the VPN server's network (often the VPN server itself or a local router/DNS resolver). |

-----

## Function

When a client connects to the OpenVPN server, the server sends this line to the client. The client software then attempts to configure the operating system to **use `10.10.0.1` as the primary DNS server** for requests going over the VPN tunnel.

This is critical because it ensures:

1. **Internal Host Resolution:** Clients can resolve internal hostnames (e.g., file server names) using the organization's private DNS server.
2. **Security/Control:** All DNS lookups are routed through a trusted DNS server, which can be important for security or filtering.

**In summary:** The server is forcing the VPN client to use **`10.10.0.1`** for all DNS lookups while connected to the VPN.
