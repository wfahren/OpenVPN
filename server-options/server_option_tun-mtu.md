# OpenVPN server option tun-mtu

The OpenVPN server directive `tun-mtu` is used to **manually set the MTU (Maximum Transmission Unit) value for the tunnel device** (the virtual network interface, usually `tun` or `tap`).

## Key Points on `tun-mtu`

The `tun-mtu` directive affects the maximum size, in bytes, of the IP packets that OpenVPN will send over the tunnel.

* **Syntax and Location:** It's typically specified in the server configuration file (e.g., `server.conf`).
  * **Example:** `tun-mtu 1500`
* **Default Value:** If not specified, OpenVPN will attempt to **automatically determine an optimal MTU**, usually by taking the MTU of the underlying physical network interface and subtracting the overhead of the tunnel protocol (like IP, UDP, and OpenVPN's own headers).
  * The standard default for a typical Ethernet-based network where the physical link MTU is 1500 bytes, is often set to **1500 bytes for the tunnel MTU**, which OpenVPN then adjusts internally, or it might default to a lower value like **1400 or 1300** to ensure maximum compatibility.
* **Purpose:** The main reason to use `tun-mtu` is to **avoid IP fragmentation** across the entire path from the client to the server and out to the final destination. Fragmentation happens when a packet is larger than the MTU of a link it traverses, causing it to be broken into smaller pieces, which increases overhead and can sometimes lead to connectivity issues or performance degradation (often called "path MTU black holes").
* **Relationship to `fragment` and `mssfix`:**
  * **`fragment`:** This directive tells OpenVPN to fragment tunnel packets *before* encapsulation and transmission. If you use `tun-mtu`, you often use `fragment` as well, setting the `fragment` value equal to or less than the `tun-mtu` value.
  * **`mssfix`:** This is generally preferred over `fragment`. It doesn't fragment the tunnel packets themselves but instead **rewrites the Maximum Segment Size (MSS) in the TCP SYN packets** passing through the tunnel. By lowering the advertised MSS, it forces the endpoints (the client and the ultimate destination server) to send smaller TCP segments, which should result in IP packets small enough to avoid fragmentation on the entire path. A common practice is to use:

        ```
        tun-mtu 1500
        mssfix 1450
        ```

        The `mssfix` value is often set to $MTU - 40$ (where 40 bytes is the minimum size of the TCP and IP headers).
* **Recommendation:** Unless you are troubleshooting specific performance issues or path MTU problems, it's often best to **let OpenVPN determine the MTU automatically** or use a conservative value like **1400** to begin with, combined with `mssfix`.

In summary, `tun-mtu` is a **low-level configuration parameter** used to explicitly define the maximum packet size for the virtual OpenVPN network interface, primarily to optimize performance and reliability by preventing packet fragmentation.
