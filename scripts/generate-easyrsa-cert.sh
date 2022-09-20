#!/bin/sh

set -e

# This script generates the following certs at these location:
#     1. Private certificate for the client - /pki/private/client1.vpn.ibm.com.key
#     2. Public certificate for the client - /pki/issued/client1.vpn.ibm.com.crt
#     3. Private certificate for the server - /pki/private/vpn-server.vpn.ibm.com.key
#     4. Public certificate for the server - /pki/issued/vpn-server.vpn.ibm.com.crt
#     5. Intermediate certificate - /pki/ca.crt
# These certs are used in the client to site VPN authentication
# Docs: https://cloud.ibm.com/docs/vpc?topic=vpc-client-to-site-authentication

# Git Clone
clone_easyrsa_repo() {
    git clone https://github.com/OpenVPN/easy-rsa.git
}

# Create a new PKI and CA:
create_pki_and_ca() {
    echo | ./easy-rsa/easyrsa3/easyrsa init-pki
    echo | ./easy-rsa/easyrsa3/easyrsa build-ca nopass
}

# Generate a VPN server certificate.
generate_server_cert() {
    echo "yes" | ./easy-rsa/easyrsa3/easyrsa build-server-full vpn-server.vpn.ibm.com nopass
}

# Generate a VPN client certificate.
generate_client_cert() {
    echo "yes" | ./easy-rsa/easyrsa3/easyrsa build-client-full client1.vpn.ibm.com nopass
}

# Cert Path:
locate_certs() {
    echo "VPN client public key is generated at path: $PWD/pki/issued/client1.vpn.ibm.com.crt"
    echo "VPN client private key is generated at path: $PWD/pki/private/client1.vpn.ibm.com.key"
    echo "Certificate File: $PWD/pki/issued/vpn-server.vpn.ibm.com.crt"
    echo "Certificate certificate's private key: $PWD/pki/private/vpn-server.vpn.ibm.com.key"
    echo "Intermediate certificate File: $PWD/pki/ca.crt"
}

init() {
    clone_easyrsa_repo
    create_pki_and_ca
    generate_server_cert
    generate_client_cert
    locate_certs
}

init
