#!/bin/bash

# TLS Certificate Setup Script
# Handles certificate generation, validation, and configuration

set -e

# Source environment variables
if [[ -f /etc/webssh2-env ]]; then
    source /etc/webssh2-env
fi

echo "[TLS] Setting up TLS certificates..."
echo "[TLS] Debug - TLS_MODE: '${TLS_MODE:-UNSET}'"

# Create certificate directory if it doesn't exist
mkdir -p /etc/nginx/certs
chown nginx:nginx /etc/nginx/certs
chmod 755 /etc/nginx/certs

# Function to validate certificate files
validate_cert() {
    local cert_file=$1
    local key_file=$2
    
    if [[ ! -f "${cert_file}" ]]; then
        echo "[TLS] ERROR: Certificate file not found: ${cert_file}"
        return 1
    fi
    
    if [[ ! -f "${key_file}" ]]; then
        echo "[TLS] ERROR: Key file not found: ${key_file}"
        return 1
    fi
    
    # Validate certificate format
    if ! openssl x509 -in "${cert_file}" -noout >/dev/null 2>&1; then
        echo "[TLS] ERROR: Invalid certificate format: ${cert_file}"
        return 1
    fi
    
    # Validate private key format
    if ! openssl rsa -in "${key_file}" -check -noout >/dev/null 2>&1 && \
       ! openssl ec -in "${key_file}" -check -noout >/dev/null 2>&1; then
        echo "[TLS] ERROR: Invalid private key format: ${key_file}"
        return 1
    fi
    
    # Check if certificate and key match
    CERT_MODULUS=$(openssl x509 -noout -modulus -in "${cert_file}" 2>/dev/null | openssl md5 2>/dev/null)
    KEY_MODULUS=$(openssl rsa -noout -modulus -in "${key_file}" 2>/dev/null | openssl md5 2>/dev/null || \
                  openssl ec -noout -pubout -in "${key_file}" 2>/dev/null | openssl md5 2>/dev/null)
    
    if [[ "${CERT_MODULUS}" != "${KEY_MODULUS}" ]]; then
        echo "[TLS] ERROR: Certificate and private key do not match"
        return 1
    fi
    
    # Check certificate expiration
    if ! openssl x509 -checkend 86400 -noout -in "${cert_file}" >/dev/null 2>&1; then
        echo "[TLS] WARNING: Certificate expires within 24 hours"
    fi
    
    echo "[TLS] ✓ Certificate and key validation passed"
    return 0
}

# Handle different TLS modes
case "${TLS_MODE}" in
    "self-signed")
        echo "[TLS] Generating self-signed certificate..."
        
        # Generate self-signed certificate if it doesn't exist
        if [[ ! -f "${TLS_CERT_PATH}" ]] || [[ ! -f "${TLS_KEY_PATH}" ]]; then
            /usr/local/bin/generate-self-signed-cert.sh
        else
            echo "[TLS] Self-signed certificate already exists, validating..."
            if ! validate_cert "${TLS_CERT_PATH}" "${TLS_KEY_PATH}"; then
                echo "[TLS] Regenerating invalid certificate..."
                rm -f "${TLS_CERT_PATH}" "${TLS_KEY_PATH}"
                /usr/local/bin/generate-self-signed-cert.sh
            fi
        fi
        ;;
        
    "provided")
        echo "[TLS] Using provided certificates..."
        
        # Check if certificates are provided as files or environment variables
        if [[ -n "${TLS_CERT_CONTENT}" ]] && [[ -n "${TLS_KEY_CONTENT}" ]]; then
            echo "[TLS] Using certificates from environment variables"
            echo "${TLS_CERT_CONTENT}" > "${TLS_CERT_PATH}"
            echo "${TLS_KEY_CONTENT}" > "${TLS_KEY_PATH}"
            
            # Handle certificate chain if provided
            if [[ -n "${TLS_CHAIN_CONTENT}" ]]; then
                echo "${TLS_CHAIN_CONTENT}" >> "${TLS_CERT_PATH}"
            fi
            
        elif [[ -f "${TLS_CERT_PATH}" ]] && [[ -f "${TLS_KEY_PATH}" ]]; then
            echo "[TLS] Using certificates from mounted files"
        else
            echo "[TLS] ERROR: No certificates provided"
            echo "[TLS] Either mount certificate files or set TLS_CERT_CONTENT/TLS_KEY_CONTENT"
            exit 1
        fi
        
        # Validate provided certificates
        if ! validate_cert "${TLS_CERT_PATH}" "${TLS_KEY_PATH}"; then
            echo "[TLS] ERROR: Provided certificates are invalid"
            exit 1
        fi
        ;;
        
    "letsencrypt")
        echo "[TLS] Let's Encrypt mode not implemented yet"
        echo "[TLS] Falling back to self-signed certificate"
        /usr/local/bin/generate-self-signed-cert.sh
        ;;
        
    *)
        echo "[TLS] ERROR: Invalid TLS_MODE: ${TLS_MODE}"
        echo "[TLS] Valid modes: self-signed, provided, letsencrypt"
        exit 1
        ;;
esac

# Set proper permissions on certificate files
chown nginx:nginx "${TLS_CERT_PATH}" "${TLS_KEY_PATH}"
chmod 644 "${TLS_CERT_PATH}"
chmod 600 "${TLS_KEY_PATH}"

# Handle certificate chain if specified
if [[ -n "${TLS_CHAIN_PATH}" ]] && [[ -f "${TLS_CHAIN_PATH}" ]]; then
    echo "[TLS] Setting up certificate chain..."
    chown nginx:nginx "${TLS_CHAIN_PATH}"
    chmod 644 "${TLS_CHAIN_PATH}"
fi

# Generate DH parameters if needed and not in FIPS mode
if [[ "${FIPS_MODE}" != "enabled" ]] && [[ ! -f /etc/nginx/certs/dhparam.pem ]]; then
    echo "[TLS] Generating DH parameters (${TLS_DH_SIZE} bits)..."
    openssl dhparam -out /etc/nginx/certs/dhparam.pem "${TLS_DH_SIZE}" 2>/dev/null &
    DH_PID=$!
    echo "[TLS] DH parameter generation started in background (PID: ${DH_PID})"
    echo "[TLS] This may take several minutes..."
fi

# Configure mTLS if enabled
if [[ "${MTLS_ENABLED}" == "true" ]]; then
    echo "[TLS] Configuring mutual TLS (mTLS)..."
    
    # Create mTLS configuration
    cat > /etc/nginx/snippets/mtls.conf << EOF
# mTLS Configuration
ssl_verify_client ${MTLS_OPTIONAL:+optional};
ssl_client_certificate ${MTLS_CA_CERT};
ssl_verify_depth ${MTLS_VERIFY_DEPTH};

# Add client certificate information to headers
proxy_set_header X-SSL-Client-Verify \$ssl_client_verify;
proxy_set_header X-SSL-Client-DN \$ssl_client_s_dn;
proxy_set_header X-SSL-Client-Serial \$ssl_client_serial;
proxy_set_header X-SSL-Client-Fingerprint \$ssl_client_fingerprint;

# Optional: CRL checking
${MTLS_CRL_PATH:+ssl_crl ${MTLS_CRL_PATH};}
EOF
    
    # Validate CA certificate
    if [[ ! -f "${MTLS_CA_CERT}" ]]; then
        echo "[TLS] ERROR: mTLS CA certificate not found: ${MTLS_CA_CERT}"
        exit 1
    fi
    
    if ! openssl x509 -in "${MTLS_CA_CERT}" -noout >/dev/null 2>&1; then
        echo "[TLS] ERROR: Invalid mTLS CA certificate format"
        exit 1
    fi
    
    chown nginx:nginx "${MTLS_CA_CERT}"
    chmod 644 "${MTLS_CA_CERT}"
    
    echo "[TLS] ✓ mTLS configuration completed"
else
    # Create empty mTLS configuration
    echo "# mTLS disabled" > /etc/nginx/snippets/mtls.conf
fi

echo "[TLS] TLS setup completed successfully"