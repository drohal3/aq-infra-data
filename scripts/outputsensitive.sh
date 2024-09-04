#!/bin/bash

# helped myself with ChatGPT!

# Retrieve and save the certificate
echo "Retrieving certificate..."
certificate_pem=$(terraform output -raw certificate_pem)
echo "$certificate_pem" > deviceCert.crt.pem
echo "Certificate saved to deviceCert.crt.pem"

# Retrieve and save the private key
echo "Retrieving private key..."
private_key=$(terraform output -raw private_key)
echo "$private_key" > privateKey.key
echo "Private key saved to privateKey.key"

# Retrieve and save the public key
echo "Retrieving public key..."
public_key=$(terraform output -raw public_key)
echo "$public_key" > publicKey.key
echo "Public key saved to publicKey.key"