#!/bin/bash

# Self-Signed Certificate Generation Script
# Generates FIPS-compliant self-signed certificates

set -e

echo "[CERT] Generating self-signed certificate..."

# Certificate parameters
CERT_PATH="${TLS_CERT_PATH:-/etc/nginx/certs/cert.pem}"
KEY_PATH="${TLS_KEY_PATH:-/etc/nginx/certs/key.pem}"
CERT_DAYS="${TLS_CERT_DAYS:-365}"
CERT_BITS="${TLS_CERT_BITS:-2048}"

# Get server hostname or use default
CERT_CN="${TLS_CERT_CN:-${NGINX_SERVER_NAME}}"
if [[ "${CERT_CN}" == "_" ]]; then
    CERT_CN="webssh2.local"
fi

# Certificate subject information
CERT_COUNTRY="${TLS_CERT_COUNTRY:-US}"
CERT_STATE="${TLS_CERT_STATE:-CA}"
CERT_CITY="${TLS_CERT_CITY:-San Francisco}"
CERT_ORG="${TLS_CERT_ORG:-WebSSH2}"
CERT_OU="${TLS_CERT_OU:-WebSSH2 Container}"

echo "[CERT] Certificate details:"
echo "[CERT]   CN: ${CERT_CN}"
echo "[CERT]   Country: ${CERT_COUNTRY}"
echo "[CERT]   State: ${CERT_STATE}"
echo "[CERT]   City: ${CERT_CITY}"
echo "[CERT]   Organization: ${CERT_ORG}"
echo "[CERT]   Organizational Unit: ${CERT_OU}"
echo "[CERT]   Key Size: ${CERT_BITS} bits"
echo "[CERT]   Valid Days: ${CERT_DAYS}"

# Create certificate directory if it doesn't exist
mkdir -p "$(dirname "${CERT_PATH}")"
mkdir -p "$(dirname "${KEY_PATH}")"

# Create subject string
SUBJECT="/C=${CERT_COUNTRY}/ST=${CERT_STATE}/L=${CERT_CITY}/O=${CERT_ORG}/OU=${CERT_OU}/CN=${CERT_CN}"

# Create OpenSSL configuration for SAN (Subject Alternative Names)
cat > /tmp/cert.conf << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = ${CERT_COUNTRY}
ST = ${CERT_STATE}
L = ${CERT_CITY}
O = ${CERT_ORG}
OU = ${CERT_OU}
CN = ${CERT_CN}

[v3_req]
keyUsage = critical, digitalSignature, keyEncipherment, keyAgreement
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${CERT_CN}
DNS.2 = localhost
DNS.3 = webssh2.local
DNS.4 = *.webssh2.local
IP.1 = 127.0.0.1
IP.2 = ::1
EOF

# Add additional SANs if specified
if [[ -n "${TLS_CERT_SAN}" ]]; then
    echo "[CERT] Adding custom Subject Alternative Names..."
    IFS=',' read -ra SANS <<< "${TLS_CERT_SAN}"
    DNS_COUNT=5
    IP_COUNT=3
    
    for san in "${SANS[@]}"; do
        san=$(echo "$san" | xargs)  # trim whitespace
        if [[ "$san" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || [[ "$san" =~ : ]]; then
            # IP address
            echo "IP.${IP_COUNT} = $san" >> /tmp/cert.conf
            ((IP_COUNT++))
        else
            # DNS name
            echo "DNS.${DNS_COUNT} = $san" >> /tmp/cert.conf
            ((DNS_COUNT++))
        fi
    done
fi

# Choose key algorithm based on FIPS mode
if [[ "${FIPS_MODE}" == "enabled" ]]; then
    echo "[CERT] Generating FIPS-compliant RSA key and certificate..."
    KEY_ALGORITHM="rsa"
    
    # Generate RSA private key
    openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:${CERT_BITS} \
        -out "${KEY_PATH}"
        
    # Generate certificate signing request
    openssl req -new -key "${KEY_PATH}" -out /tmp/cert.csr -config /tmp/cert.conf
    
    # Generate self-signed certificate
    openssl x509 -req -in /tmp/cert.csr -signkey "${KEY_PATH}" -out "${CERT_PATH}" \
        -days "${CERT_DAYS}" -extensions v3_req -extfile /tmp/cert.conf
        
else
    echo "[CERT] Generating elliptic curve key and certificate (non-FIPS)..."
    KEY_ALGORITHM="ec"
    
    # Generate EC private key (P-256 curve)
    openssl ecparam -genkey -name prime256v1 -out "${KEY_PATH}"
    
    # Generate certificate signing request
    openssl req -new -key "${KEY_PATH}" -out /tmp/cert.csr -config /tmp/cert.conf
    
    # Generate self-signed certificate
    openssl x509 -req -in /tmp/cert.csr -signkey "${KEY_PATH}" -out "${CERT_PATH}" \
        -days "${CERT_DAYS}" -extensions v3_req -extfile /tmp/cert.conf
fi

# Clean up temporary files
rm -f /tmp/cert.csr /tmp/cert.conf

# Set proper permissions
chown nginx:nginx "${CERT_PATH}" "${KEY_PATH}"
chmod 644 "${CERT_PATH}"
chmod 600 "${KEY_PATH}"

# Verify certificate
echo "[CERT] Verifying generated certificate..."

if openssl x509 -in "${CERT_PATH}" -noout -text | grep -q "${CERT_CN}"; then
    echo "[CERT] ✓ Certificate generated successfully"
else
    echo "[CERT] ERROR: Certificate verification failed"
    exit 1
fi

# Display certificate information
echo "[CERT] Certificate Information:"
openssl x509 -in "${CERT_PATH}" -noout -subject -dates -fingerprint -sha256

# Display Subject Alternative Names
echo "[CERT] Subject Alternative Names:"
openssl x509 -in "${CERT_PATH}" -noout -text | grep -A 10 "Subject Alternative Name" || echo "[CERT] No SAN found"

echo "[CERT] Self-signed certificate generation completed"
echo "[CERT] Certificate: ${CERT_PATH}"
echo "[CERT] Private Key: ${KEY_PATH}"
echo "[CERT] ⚠ This is a self-signed certificate - browsers will show security warnings"