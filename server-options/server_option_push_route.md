# OpenVPN option push route

```text
push "route 10.10.0.0 255.255.255.0"
```

This directive, typically found in the **OpenVPN server's configuration file**, tells the server to force connecting clients to **add a specific route** to their local routing table.

-----

## Explanation of `push "route..."`

The purpose of this command is to ensure that the client knows **how to reach resources** on the remote network (the network the OpenVPN server is connected to).

| Part | Meaning |
| :--- | :--- |
| **`push`** | Instructs the server to send this configuration setting to the client upon successful connection. |
| **`"route"`** | The specific command being pushed, telling the client to add a new network route. |
| **`10.10.0.0`** | This is the **Network Address** (Destination) for the remote network. Any traffic destined for an IP starting with 10.10.0.x will use this route. |
| **`255.255.255.0`** | This is the **Netmask** that defines the size of the remote network. A `255.255.255.0` netmask means the network encompasses all 254 usable addresses from `10.10.0.1` to `10.10.0.254`. |

-----

## How the Route Works

When the client receives this command:

1. It adds an entry to its operating system's **routing table**.
2. The entry specifies that any data packets destined for the **`10.10.0.0/24`** network must be sent through the **VPN tunnel** (the virtual network interface created by OpenVPN, e.g., `tun0`).

**In essence:** This line ensures that when the VPN is active, the client can access the server's internal network (like file servers, databases, or printers that use `10.10.0.x` addresses) without accidentally routing that traffic through its regular internet connection.
