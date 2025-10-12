# OpenVPN server option push route

```text
push "route 10.10.0.0 255.255.255.0"
```

This directive instructs the **OpenVPN server to automatically add a routing rule** to every connecting client's operating system.

-----

## Explanation

The purpose of this command is to ensure that the client knows exactly **how to reach the remote internal network** (the network where the server resides) through the encrypted VPN tunnel.

| Component | Meaning |
| :--- | :--- |
| **`push`** | Tells the server to **send** the enclosed command string to the client. This is how the server dynamically configures the client's network settings. |
| **`"route"`** | The command being pushed, instructing the client to **add a new network route** to its local routing table. |
| **`10.10.0.0`** | This is the **Network Address** (the destination). Any traffic destined for an IP address starting with $10.10.0.x$ will use this route. This is the address of the remote network you want clients to access. |
| **`255.255.255.0`** | This is the **Netmask** (the subnet mask). It defines the size of the remote network, which, in this case (a $/24$ subnet), includes all addresses from $10.10.0.1$ to $10.10.0.254$. |

-----

## How it Works

When the VPN client connects:

1. The client receives this instruction from the server.
2. It creates a rule in its OS routing table: "To reach the **$10.10.0.0/24$** network, send the traffic through the **VPN tunnel**."

Essentially, this is how you grant clients access to your private LAN that sits behind the OpenVPN server. Without this rule, the client wouldn't know to send traffic for the $10.10.0.x$ addresses over the VPN, and the connection would fail.
