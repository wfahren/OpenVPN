#!/bin/bash

# --- Configuration for OpenVPN Client Config Generator ---
# This script generates an all-in-one OpenVPN client configuration file (.ovpn).
# It embeds the CA certificate, client certificate, client key, and TLS-crypt key into
# a base configuration file.

# Check if the client identifier (first argument) is provided
if [ -z "$1" ]; then
    echo "ERROR: Missing client identifier." >&2
    echo "Usage: $0 <client_name>" >&2
    exit 1
fi

# Configuration variables (update these to match your installation)
EASY_RSA_DIR="$HOME/easy-rsa"                    # Location of easy-rsa directory
CLIENT_CONFIG_DIR="$HOME/easy-rsa"               # Location of client-config directory
OUTPUT_DIR="$HOME/easy-rsa/client-ovpn-files"    # Location for client .ovpn files
BASE_CONFIG="$HOME/easy-rsa/client-base.conf"    # Location of client OpenVPN base config

CLIENT_NAME="$1"
CA_CRT_PATH="${EASY_RSA_DIR}/pki/ca.crt"
CERT_DIR="${EASY_RSA_DIR}/pki/issued"
KEY_DIR="${EASY_RSA_DIR}/pki/private"
TA_KEY_PATH="${EASY_RSA_DIR}/ta.key"

# Check if the base configuration file exists
if [ ! -f "${BASE_CONFIG}" ]; then
    echo "ERROR: Base configuration file not found: ${BASE_CONFIG}" >&2
    exit 1
fi

# Check for required files
declare -a REQUIRED_FILES=(
    "${CA_CRT_PATH}"
    "${CERT_DIR}/${CLIENT_NAME}.crt"
    "${KEY_DIR}/${CLIENT_NAME}.key"
    "${TA_KEY_PATH}"
)

echo "Validating required files for ${CLIENT_NAME}..."
for file_path in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "${file_path}" ]; then
        echo "ERROR: Required file not found: ${file_path}" >&2
        exit 1
    fi
done

# Ensure the output directory exists
mkdir -p "${OUTPUT_DIR}"

# --- File Generation ---
OUTPUT_FILE="${OUTPUT_DIR}/${CLIENT_NAME}.ovpn"

echo "Generating OpenVPN configuration for client: ${CLIENT_NAME}..."

# Use cat with process substitution to embed all components into the final .ovpn file
# The keys and certificates are wrapped in their respective <tag>...</tag> markers.
cat "${BASE_CONFIG}" \
    <(echo -e '<ca>') \
    "${CA_CRT_PATH}" \
    <(echo -e '</ca>\n<cert>') \
    "${CERT_DIR}/${CLIENT_NAME}.crt" \
    <(echo -e '</cert>\n<key>') \
    "${KEY_DIR}/${CLIENT_NAME}.key" \
    <(echo -e '</key>\n<tls-crypt>') \
    "${TA_KEY_PATH}" \
    <(echo -e '</tls-crypt>') \
    > "${OUTPUT_FILE}"

# --- Completion and Status ---
if [ $? -eq 0 ]; then
    echo "SUCCESS: Configuration saved to ${OUTPUT_FILE}"
    # Set secure permissions for the generated file
    chmod 600 "${OUTPUT_FILE}"
else
    echo "FAILURE: An error occurred during file generation." >&2
    exit 1
fi

exit 0
