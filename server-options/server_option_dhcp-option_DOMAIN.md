# OpenVPN option dhcp-option DOMAIN

```test
push "dhcp-option DOMAIN lan"
```

This directive tells the OpenVPN server to instruct the connecting client to use **`lan`** as a **DNS search domain suffix**.

## Explanation of `push "dhcp-option DOMAIN lan"`

This line is placed in the **server's OpenVPN configuration file** and serves to simplify access to resources on the server's network for the client.

| Part | Meaning |
| :--- | :--- |
| **`push`** | This command sends the enclosed configuration setting from the server to the client upon connection. |
| **`"dhcp-option DOMAIN"`** | This is the specific DHCP option code that tells the client's operating system (OS) to set a new **DNS search suffix** or **domain name**. |
| **`lan`** | This is the specific domain suffix that will be used. |

-----

### How It Works

When a client connects to the VPN:

1. The OpenVPN server sends the `push` command to the client.
2. The client's operating system adds **`.lan`** to its list of DNS search domains.

This allows the user to access internal network resources using their **short name** instead of their Fully Qualified Domain Name (FQDN).

#### Example

If you have an internal server with the FQDN **`fileserver.lan`**:

* **Before** this option is applied, you must type: `fileserver.lan`.
* **After** this option is applied, you can simply type: **`fileserver`**.

If the client OS tries to resolve `fileserver` and fails, it automatically appends the search suffix and tries again with `fileserver.lan`, which the DNS server can then resolve.

The value **`lan`** is a very common, simple, and often default domain suffix used in many small or home networks, though any valid internal domain name (e.g., `corp.local`, `internal.company.com`) could be used here.
