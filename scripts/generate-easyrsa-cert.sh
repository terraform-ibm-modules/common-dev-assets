#!/bin/sh

set -e

# Docs: https://cloud.ibm.com/docs/vpc?topic=vpc-client-to-site-authentication

REF_PATH=$1

# Git Clone
clone_easyrsa_repo() {
    git clone https://github.com/OpenVPN/easy-rsa.git
}

# Create a new PKI and CA:
create_pki_and_ca() {
    echo | ./"${REF_PATH}"/easy-rsa/easyrsa3/easyrsa init-pki
    echo | ./"${REF_PATH}"/easy-rsa/easyrsa3/easyrsa build-ca nopass
}

# Generate a VPN server certificate.
generate_server_cert() {
    echo "yes" | ./"${REF_PATH}"/easy-rsa/easyrsa3/easyrsa build-server-full vpn-server.vpn.ibm.com nopass
}

# Generate a VPN client certificate.
generate_client_cert() {
    echo "yes" | ./"${REF_PATH}"/easy-rsa/easyrsa3/easyrsa build-client-full client1.vpn.ibm.com nopass
}

# Cert Path:
locate_certs() {
    echo "VPN client public key is generated at path: ""$PWD""/pki/issued/client1.vpn.ibm.com.crt"
    echo "VPN client private key is generated at path: ""$PWD""/pki/private/client1.vpn.ibm.com.key"
    # echo $PWD
    echo "Certificate File: ""$PWD""/pki/issued/vpn-server.vpn.ibm.com.crt"
    echo "Certificate certificate's private key: ""$PWD""/pki/private/vpn-server.vpn.ibm.com.key"
    echo "Intermediate certificate File: ""$PWD""/pki/ca.crt"
}

init() {
    clone_easyrsa_repo
    create_pki_and_ca
    generate_server_cert
    generate_client_cert
    locate_certs
}

init
