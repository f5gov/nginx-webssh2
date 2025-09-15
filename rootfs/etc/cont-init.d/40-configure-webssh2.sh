#!/bin/bash

# WebSSH2 Configuration Script
# Sets up WebSSH2 configuration from environment variables

set -e

# Source environment variables
if [[ -f /etc/webssh2-env ]]; then
    source /etc/webssh2-env
fi

echo "[WebSSH2] Configuring WebSSH2..."

# Ensure WebSSH2 directory exists and has correct permissions
chown -R webssh2:webssh2 /usr/src/webssh2
chmod 755 /usr/src/webssh2

# Create log directory for WebSSH2
mkdir -p /var/log/webssh2
chown webssh2:webssh2 /var/log/webssh2
chmod 755 /var/log/webssh2

# Set default values for WebSSH2 environment variables
export WEBSSH2_LISTEN_IP=${WEBSSH2_LISTEN_IP:-127.0.0.1}
export WEBSSH2_LISTEN_PORT=${WEBSSH2_LISTEN_PORT:-2222}
export WEBSSH2_SSH_HOST=${WEBSSH2_SSH_HOST:-}
export WEBSSH2_SSH_PORT=${WEBSSH2_SSH_PORT:-22}
export WEBSSH2_SSH_TERM=${WEBSSH2_SSH_TERM:-xterm-256color}
export WEBSSH2_SSH_READY_TIMEOUT=${WEBSSH2_SSH_READY_TIMEOUT:-20000}
export WEBSSH2_SSH_KEEPALIVE_INTERVAL=${WEBSSH2_SSH_KEEPALIVE_INTERVAL:-120000}
export WEBSSH2_SSH_KEEPALIVE_COUNT_MAX=${WEBSSH2_SSH_KEEPALIVE_COUNT_MAX:-10}
export WEBSSH2_SSH_ALGORITHMS_PRESET=${WEBSSH2_SSH_ALGORITHMS_PRESET:-modern}

# Session configuration
export WEBSSH2_SESSION_NAME=${WEBSSH2_SESSION_NAME:-webssh2.sid}

# Generate session secret if not provided
if [[ -z "${WEBSSH2_SESSION_SECRET}" ]]; then
    echo "[WebSSH2] Generating random session secret..."
    export WEBSSH2_SESSION_SECRET=$(openssl rand -base64 32)
    echo "[WebSSH2] ⚠ Using generated session secret (not persistent)"
    echo "[WebSSH2] For production, set WEBSSH2_SESSION_SECRET environment variable"
fi

# Header configuration
export WEBSSH2_HEADER_TEXT=${WEBSSH2_HEADER_TEXT:-}
export WEBSSH2_HEADER_BACKGROUND=${WEBSSH2_HEADER_BACKGROUND:-green}

# Options configuration
export WEBSSH2_OPTIONS_CHALLENGE_BUTTON=${WEBSSH2_OPTIONS_CHALLENGE_BUTTON:-true}
export WEBSSH2_OPTIONS_AUTO_LOG=${WEBSSH2_OPTIONS_AUTO_LOG:-false}
export WEBSSH2_OPTIONS_ALLOW_REAUTH=${WEBSSH2_OPTIONS_ALLOW_REAUTH:-true}
export WEBSSH2_OPTIONS_ALLOW_RECONNECT=${WEBSSH2_OPTIONS_ALLOW_RECONNECT:-true}
export WEBSSH2_OPTIONS_ALLOW_REPLAY=${WEBSSH2_OPTIONS_ALLOW_REPLAY:-true}

# CORS configuration
if [[ -z "${WEBSSH2_HTTP_ORIGINS}" ]]; then
    # Default to allowing same origin and common local development origins
    export WEBSSH2_HTTP_ORIGINS="https://${NGINX_SERVER_NAME}:${NGINX_LISTEN_PORT},https://localhost:${NGINX_LISTEN_PORT},https://127.0.0.1:${NGINX_LISTEN_PORT}"
fi

# Legacy PORT support
export PORT=${WEBSSH2_LISTEN_PORT}

# Debug configuration
export DEBUG=${DEBUG:-}

# User configuration (these will be empty by default for security)
export WEBSSH2_USER_NAME=${WEBSSH2_USER_NAME:-}
export WEBSSH2_USER_PASSWORD=${WEBSSH2_USER_PASSWORD:-}
export WEBSSH2_USER_PRIVATE_KEY=${WEBSSH2_USER_PRIVATE_KEY:-}
export WEBSSH2_USER_PASSPHRASE=${WEBSSH2_USER_PASSPHRASE:-}

# Algorithm preset configuration for FIPS mode
if [[ "${FIPS_MODE}" == "enabled" ]]; then
    echo "[WebSSH2] Configuring SSH algorithms for FIPS mode..."
    
    # Override algorithm preset for FIPS compliance
    if [[ "${WEBSSH2_SSH_ALGORITHMS_PRESET}" == "modern" ]] || [[ "${WEBSSH2_SSH_ALGORITHMS_PRESET}" == "strict" ]]; then
        echo "[WebSSH2] Using FIPS-compatible algorithm preset"
    else
        echo "[WebSSH2] Forcing 'modern' algorithm preset for FIPS compliance"
        export WEBSSH2_SSH_ALGORITHMS_PRESET=modern
    fi
    
    # Set specific FIPS-approved algorithms if needed
    export WEBSSH2_SSH_ALGORITHMS_KEX=${WEBSSH2_SSH_ALGORITHMS_KEX:-"ecdh-sha2-nistp256,ecdh-sha2-nistp384,ecdh-sha2-nistp521"}
    export WEBSSH2_SSH_ALGORITHMS_CIPHER=${WEBSSH2_SSH_ALGORITHMS_CIPHER:-"aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes128-ctr"}
    export WEBSSH2_SSH_ALGORITHMS_HMAC=${WEBSSH2_SSH_ALGORITHMS_HMAC:-"hmac-sha2-256,hmac-sha2-512"}
    export WEBSSH2_SSH_ALGORITHMS_COMPRESS=${WEBSSH2_SSH_ALGORITHMS_COMPRESS:-"none,zlib@openssh.com"}
    export WEBSSH2_SSH_ALGORITHMS_SERVER_HOST_KEY=${WEBSSH2_SSH_ALGORITHMS_SERVER_HOST_KEY:-"ecdsa-sha2-nistp256,ecdsa-sha2-nistp384,ecdsa-sha2-nistp521,ssh-rsa"}
fi

# Validate configuration
echo "[WebSSH2] Validating configuration..."

# Check if required Node.js modules are available
if [[ ! -d "/usr/src/webssh2/node_modules" ]]; then
    echo "[WebSSH2] ERROR: Node.js modules not found"
    echo "[WebSSH2] Run 'npm install' in WebSSH2 directory"
    exit 1
fi

# Check if WebSSH2 main file exists
if [[ ! -f "/usr/src/webssh2/dist/index.js" ]]; then
    echo "[WebSSH2] ERROR: WebSSH2 main file not found: /usr/src/webssh2/dist/index.js"
    exit 1
fi

# Validate port numbers
if ! [[ "${WEBSSH2_LISTEN_PORT}" =~ ^[0-9]+$ ]] || \
   [[ "${WEBSSH2_LISTEN_PORT}" -lt 1 ]] || \
   [[ "${WEBSSH2_LISTEN_PORT}" -gt 65535 ]]; then
    echo "[WebSSH2] ERROR: Invalid WEBSSH2_LISTEN_PORT: ${WEBSSH2_LISTEN_PORT}"
    exit 1
fi

if ! [[ "${WEBSSH2_SSH_PORT}" =~ ^[0-9]+$ ]] || \
   [[ "${WEBSSH2_SSH_PORT}" -lt 1 ]] || \
   [[ "${WEBSSH2_SSH_PORT}" -gt 65535 ]]; then
    echo "[WebSSH2] ERROR: Invalid WEBSSH2_SSH_PORT: ${WEBSSH2_SSH_PORT}"
    exit 1
fi

# Validate IP address format
if [[ ! "${WEBSSH2_LISTEN_IP}" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] && \
   [[ "${WEBSSH2_LISTEN_IP}" != "0.0.0.0" ]] && \
   [[ "${WEBSSH2_LISTEN_IP}" != "127.0.0.1" ]]; then
    echo "[WebSSH2] ERROR: Invalid WEBSSH2_LISTEN_IP: ${WEBSSH2_LISTEN_IP}"
    exit 1
fi

# Test Node.js version compatibility
NODE_VERSION=$(node --version | sed 's/v//')
NODE_MAJOR_VERSION=$(echo "${NODE_VERSION}" | cut -d. -f1)

if [[ "${NODE_MAJOR_VERSION}" -lt 18 ]]; then
    echo "[WebSSH2] ERROR: Node.js version ${NODE_VERSION} is not supported"
    echo "[WebSSH2] WebSSH2 requires Node.js 18 or higher"
    exit 1
fi

echo "[WebSSH2] ✓ Configuration validation passed"

echo "[WebSSH2] WebSSH2 configuration completed successfully"

# Output configuration summary
echo "[WebSSH2] Configuration Summary:"
echo "[WebSSH2]   Listen Address: ${WEBSSH2_LISTEN_IP}:${WEBSSH2_LISTEN_PORT}"
echo "[WebSSH2]   SSH Host: ${WEBSSH2_SSH_HOST:-"(dynamic)"}"
echo "[WebSSH2]   SSH Port: ${WEBSSH2_SSH_PORT}"
echo "[WebSSH2]   Terminal: ${WEBSSH2_SSH_TERM}"
echo "[WebSSH2]   Algorithm Preset: ${WEBSSH2_SSH_ALGORITHMS_PRESET}"
echo "[WebSSH2]   Session Name: ${WEBSSH2_SESSION_NAME}"
echo "[WebSSH2]   Challenge Button: ${WEBSSH2_OPTIONS_CHALLENGE_BUTTON}"
echo "[WebSSH2]   Allow Reauth: ${WEBSSH2_OPTIONS_ALLOW_REAUTH}"
echo "[WebSSH2]   Allow Reconnect: ${WEBSSH2_OPTIONS_ALLOW_RECONNECT}"
echo "[WebSSH2]   Allow Replay: ${WEBSSH2_OPTIONS_ALLOW_REPLAY}"
echo "[WebSSH2]   Auto Log: ${WEBSSH2_OPTIONS_AUTO_LOG}"
echo "[WebSSH2]   Header Background: ${WEBSSH2_HEADER_BACKGROUND}"
echo "[WebSSH2]   FIPS Mode: ${FIPS_MODE}"
echo "[WebSSH2]   Node.js Version: ${NODE_VERSION}"