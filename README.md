# OpenVPN Server Setup Guide

This repository contains a comprehensive guide and supporting script for setting up a secure OpenVPN server on a Linux host, utilizing modern **Elliptic Curve Cryptography (ECC)** and the **`tls-crypt`** security feature.

***

## 📘 Guide Summary

This setup process covers three main phases:

1. **Server Setup:** Installing OpenVPN and Easy-RSA, configuring the Public Key Infrastructure (PKI), and generating all necessary server certificates, keys, and the `ta.key` for `tls-crypt`.
2. **Server Configuration:** Creating and configuring the main OpenVPN server configuration file (`server.conf`).
3. **Client Creation:** Using the included BASH script to automatically generate all-in-one client configuration files.

***

## 🛠️ make-client-ovpn.sh

The included BASH script, **`make-client-ovpn.sh`**, simplifies client configuration management by automating the creation of secure, all-in-one OpenVPN client files (`.ovpn`).

### Key Features

* **All-in-One File:** Generates a single `.ovpn` file that embeds the CA certificate, client certificate, client key, and the `tls-crypt` key (`ta.key`).
* **Inline Config:** Uses your base client configuration file (`client-base.conf`) to create a ready-to-use client profile.
* **Security Focused:** Ensures all client connections benefit from the strong ECC keys and the authenticated encryption provided by `tls-crypt`.

### Usage

To generate a new client configuration, run the script from your `~/easy-rsa` directory, passing the client name as the only argument (this name must match the name used when generating the client certificate):

```bash
cd ~/easy-rsa
./easyrsa build-client-full client-thinkpad nopass
./make-client-ovpn.sh client-thinkpad
````

**note:** You need to first configure the system. Click on the link at the bottom on this page and follow the steps outlined.

**Output:**

The resulting client file will be saved to the `~/easy-rsa/client-ovpn-files` directory:

`~/easy-rsa/client-ovpn-files/client-thinkpad.ovpn`

***

### Trouble Shooting

If you've followed the setup and have a VPN connection, you can ping the client, but web sites still won't load. This is often an MTU issue. [Follow the steps in this guide to troulbe shoot](https://github.com/wfahren/OpenVPN/blob/main/web_sites_not_loading.md)

## 🚀 Get Started

[Click here to get started with the setup\!](https://github.com/wfahren/OpenVPN/blob/main/openvpn-install.md)
