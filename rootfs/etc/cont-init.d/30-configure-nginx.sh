#!/bin/bash

# NGINX Configuration Script
# Processes templates and configures NGINX with environment variables

set -e

# Source environment variables
if [[ -f /etc/webssh2-env ]]; then
    source /etc/webssh2-env
fi

echo "[NGINX] Configuring NGINX..."

# Debug: Show available environment variables
echo "[NGINX] Debug - Environment variables:"
echo "[NGINX] TLS_MODE: '${TLS_MODE:-UNSET}'"
echo "[NGINX] NGINX_SERVER_NAME: '${NGINX_SERVER_NAME:-UNSET}'"
echo "[NGINX] WEBSSH2_LISTEN_PORT: '${WEBSSH2_LISTEN_PORT:-UNSET}'"

# Function to substitute environment variables in template files
process_template() {
    local template_file=$1
    local output_file=$2
    
    if [[ ! -f "${template_file}" ]]; then
        echo "[NGINX] ERROR: Template file not found: ${template_file}"
        return 1
    fi
    
    echo "[NGINX] Processing template: ${template_file} -> ${output_file}"
    
    # Use envsubst with specific variable list to avoid substituting nginx variables
    envsubst '$NGINX_WORKER_PROCESSES $NGINX_WORKER_CONNECTIONS $NGINX_KEEPALIVE_TIMEOUT $NGINX_CLIENT_MAX_BODY_SIZE $NGINX_PROXY_READ_TIMEOUT $NGINX_PROXY_SEND_TIMEOUT $NGINX_RATE_LIMIT $NGINX_RATE_LIMIT_BURST $NGINX_CONN_LIMIT $NGINX_GZIP $NGINX_ERROR_LOG_LEVEL $NGINX_SERVER_NAME $NGINX_LISTEN_PORT $WEBSSH2_LISTEN_PORT $TLS_CERT_PATH $TLS_KEY_PATH $SECURITY_HEADERS $HSTS_MAX_AGE $CSP_POLICY' < "${template_file}" > "${output_file}"
    
    # Validate the resulting configuration (only for main nginx.conf)
    if [[ "${output_file}" == "/etc/nginx/nginx.conf" ]]; then
        if ! nginx -t >/dev/null 2>&1; then
            echo "[NGINX] ERROR: Invalid NGINX configuration generated from ${template_file}"
            return 1
        fi
    fi
    
    return 0
}

# Set default values for environment variables that might be empty
export NGINX_WORKER_PROCESSES=${NGINX_WORKER_PROCESSES:-auto}
export NGINX_WORKER_CONNECTIONS=${NGINX_WORKER_CONNECTIONS:-1024}
export NGINX_KEEPALIVE_TIMEOUT=${NGINX_KEEPALIVE_TIMEOUT:-65}
export NGINX_CLIENT_MAX_BODY_SIZE=${NGINX_CLIENT_MAX_BODY_SIZE:-1m}
export NGINX_PROXY_READ_TIMEOUT=${NGINX_PROXY_READ_TIMEOUT:-3600s}
export NGINX_PROXY_SEND_TIMEOUT=${NGINX_PROXY_SEND_TIMEOUT:-3600s}
export NGINX_RATE_LIMIT=${NGINX_RATE_LIMIT:-10r/s}
export NGINX_RATE_LIMIT_BURST=${NGINX_RATE_LIMIT_BURST:-20}
export NGINX_CONN_LIMIT=${NGINX_CONN_LIMIT:-100}
export NGINX_GZIP=${NGINX_GZIP:-on}
export NGINX_ERROR_LOG_LEVEL=${NGINX_ERROR_LOG_LEVEL:-warn}
export NGINX_SERVER_NAME=${NGINX_SERVER_NAME:-_}

# Security headers configuration
export SECURITY_HEADERS=${SECURITY_HEADERS:-true}
export HSTS_MAX_AGE=${HSTS_MAX_AGE:-31536000}
export CSP_POLICY=${CSP_POLICY:-"default-src 'self'; script-src 'self' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; connect-src 'self' ws: wss:; font-src 'self'; img-src 'self' data:;"}

# WebSSH2 backend configuration
export WEBSSH2_LISTEN_PORT=${WEBSSH2_LISTEN_PORT:-2222}

# TLS certificate paths (set after certificate generation)
export TLS_CERT_PATH=${TLS_CERT_PATH:-/etc/nginx/certs/server.crt}
export TLS_KEY_PATH=${TLS_KEY_PATH:-/etc/nginx/certs/server.key}

# Process main nginx.conf template
process_template /etc/nginx/nginx.conf.template /etc/nginx/nginx.conf

# Process WebSSH2 server configuration
process_template /etc/nginx/conf.d/webssh2.conf.template /etc/nginx/conf.d/webssh2.conf

# Process security headers template
process_template /etc/nginx/snippets/security-headers.conf.template /etc/nginx/snippets/security-headers.conf

# Configure FIPS-specific cipher suites if in FIPS mode
if [[ "${FIPS_MODE}" == "enabled" ]]; then
    echo "[NGINX] Configuring FIPS-approved cipher suites..."
    
    # Override default ciphers with FIPS-approved ones
    FIPS_CIPHERS=${TLS_CIPHERS:-"ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-GCM-SHA256"}
    
    # Update SSL parameters with FIPS ciphers
    sed -i "s/ssl_ciphers .*/ssl_ciphers ${FIPS_CIPHERS};/" /etc/nginx/snippets/ssl-params.conf
    
    # Ensure only TLS 1.2 and 1.3 are enabled in FIPS mode
    sed -i "s/ssl_protocols .*/ssl_protocols TLSv1.2 TLSv1.3;/" /etc/nginx/snippets/ssl-params.conf
    
    echo "[NGINX] ✓ FIPS cipher suites configured"
fi

# Configure access logging
if [[ "${NGINX_ACCESS_LOG}" == "off" ]]; then
    echo "[NGINX] Disabling access logs"
    sed -i 's/access_log \/var\/log\/nginx\/access.log main;/access_log off;/' /etc/nginx/nginx.conf
fi

# Test NGINX configuration
echo "[NGINX] Testing NGINX configuration..."
if nginx -t; then
    echo "[NGINX] ✓ NGINX configuration is valid"
else
    echo "[NGINX] ERROR: NGINX configuration test failed"
    exit 1
fi

# Create log directory and set permissions
mkdir -p /var/log/nginx
chown -R nginx:nginx /var/log/nginx
chmod 755 /var/log/nginx

# Create run directory for PID file
mkdir -p /run/nginx
chown nginx:nginx /run/nginx
chmod 755 /run/nginx

# Set permissions on configuration files
chown -R nginx:nginx /etc/nginx
find /etc/nginx -type f -name "*.conf" -exec chmod 644 {} \;
find /etc/nginx -type d -exec chmod 755 {} \;

# Ensure certificate files have correct permissions if they exist
if [[ -f "${TLS_CERT_PATH}" ]]; then
    chown nginx:nginx "${TLS_CERT_PATH}"
    chmod 644 "${TLS_CERT_PATH}"
fi

if [[ -f "${TLS_KEY_PATH}" ]]; then
    chown nginx:nginx "${TLS_KEY_PATH}"
    chmod 600 "${TLS_KEY_PATH}"
fi

echo "[NGINX] NGINX configuration completed successfully"

# Output configuration summary
echo "[NGINX] Configuration Summary:"
echo "[NGINX]   Listen Port: ${NGINX_LISTEN_PORT} (HTTPS only)"
echo "[NGINX]   Server Name: ${NGINX_SERVER_NAME}"
echo "[NGINX]   Worker Processes: ${NGINX_WORKER_PROCESSES}"
echo "[NGINX]   Worker Connections: ${NGINX_WORKER_CONNECTIONS}"
echo "[NGINX]   Rate Limit: ${NGINX_RATE_LIMIT} (burst: ${NGINX_RATE_LIMIT_BURST})"
echo "[NGINX]   Connection Limit: ${NGINX_CONN_LIMIT}"
echo "[NGINX]   Gzip: ${NGINX_GZIP}"
echo "[NGINX]   TLS Mode: ${TLS_MODE}"
echo "[NGINX]   FIPS Mode: ${FIPS_MODE}"
echo "[NGINX]   mTLS: ${MTLS_ENABLED}"