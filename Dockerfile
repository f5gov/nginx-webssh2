# Multi-stage build for TypeScript compilation
# Stage 1: Build WebSSH2 TypeScript
FROM node:22-alpine AS builder

ARG WEBSSH2_VERSION

WORKDIR /build

# Copy prebuilt WebSSH2 artifact contents
COPY ./vendor/webssh2/package*.json ./
COPY ./vendor/webssh2/scripts/ ./scripts/
COPY ./vendor/webssh2/dist/ ./dist/
COPY ./vendor/webssh2/manifest.json ./manifest.json

# Install production dependencies for target platform
RUN npm ci --omit=dev --ignore-scripts --no-audit --no-fund && \
    npm run prepare:runtime && \
    npm prune --omit=dev && \
    rm -rf node_modules/.cache

# Stage 2: Production container
# NGINX + WebSSH2 Container with FIPS Support
# Base: Red Hat UBI9 Minimal with Node.js 22, NGINX, and s6-overlay
FROM registry.access.redhat.com/ubi9/ubi-minimal:latest

# Build arguments
ARG BUILD_DATE
ARG BUILD_VERSION
ARG WEBSSH2_VERSION
ARG VCS_REF

# Metadata
LABEL maintainer="F5 Government Solutions Team" \
      name="nginx-webssh2" \
      version="${BUILD_VERSION:-1.0.0}" \
      description="NGINX + WebSSH2 container with FIPS 140-2 support" \
      vendor="F5 Government Solutions" \
      license="MIT" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.version="${BUILD_VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      webssh2.version="${WEBSSH2_VERSION}"

# Set environment variables
ENV S6_OVERLAY_VERSION=3.1.6.2 \
    NODE_VERSION=22 \
    NGINX_VERSION=1.24 \
    PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# Install base packages, enable FIPS, and install NGINX
RUN microdnf update -y && \
    microdnf install -y \
        tar \
        findutils \
        ca-certificates \
        gnupg2 \
        openssl \
        procps-ng \
        shadow-utils \
        util-linux \
        xz \
        gettext && \
    # Enable FIPS mode for UBI9 with OpenSSL 3.0 provider model
    (fips-mode-setup --enable --no-bootcfg 2>/dev/null || echo "FIPS setup not available in container") && \
    (update-crypto-policies --set FIPS 2>/dev/null || echo "Crypto policies not available in container") && \
    # Verify OpenSSL 3.0 FIPS provider
    (openssl list -providers 2>/dev/null | grep -q "fips" && echo "FIPS provider detected" || echo "FIPS provider not available") && \
    echo "UBI9 FIPS mode setup attempted" && \
    # Create nginx repository configuration
    printf '[nginx-stable]\n\
name=nginx stable repo\n\
baseurl=http://nginx.org/packages/rhel/9/$basearch/\n\
gpgcheck=1\n\
enabled=1\n\
gpgkey=https://nginx.org/keys/nginx_signing.key\n\
module_hotfixes=true\n\
\n\
[nginx-mainline]\n\
name=nginx mainline repo\n\
baseurl=http://nginx.org/packages/mainline/rhel/9/$basearch/\n\
gpgcheck=1\n\
enabled=0\n\
gpgkey=https://nginx.org/keys/nginx_signing.key\n\
module_hotfixes=true\n' > /etc/yum.repos.d/nginx.repo && \
    # Import NGINX GPG key and install NGINX
    rpm --import https://nginx.org/keys/nginx_signing.key && \
    microdnf install -y nginx && \
    nginx -v && \
    microdnf clean all

# Install Node.js 22 from NodeSource
RUN curl -fsSL https://rpm.nodesource.com/setup_22.x | bash - && \
    microdnf install -y nodejs && \
    node --version && \
    npm --version && \
    microdnf clean all

# Install s6-overlay for process supervision
# Determine architecture and download appropriate binary
# Note: ARM64 uses different tar flags to work around QEMU emulation issues in CI
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
        S6_ARCH="x86_64"; \
        TAR_OPTS="-Jxpf"; \
    elif [ "$ARCH" = "aarch64" ]; then \
        S6_ARCH="aarch64"; \
        TAR_OPTS="-Jxf --no-same-owner"; \
    else \
        echo "Unsupported architecture: $ARCH" && exit 1; \
    fi && \
    curl -L -o /tmp/s6-overlay-noarch.tar.xz \
        https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz && \
    curl -L -o /tmp/s6-overlay-${S6_ARCH}.tar.xz \
        https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_ARCH}.tar.xz && \
    tar -C / $TAR_OPTS /tmp/s6-overlay-noarch.tar.xz && \
    tar -C / $TAR_OPTS /tmp/s6-overlay-${S6_ARCH}.tar.xz && \
    rm /tmp/s6-overlay-*.tar.xz

# Create users, groups, and directories
RUN groupadd --gid 1001 webssh2 && \
    useradd --uid 1001 --gid webssh2 --shell /bin/bash --create-home webssh2 && \
    usermod -a -G nginx webssh2 && \
    mkdir -p \
        /usr/src/webssh2 \
        /etc/nginx/certs \
        /etc/nginx/dhparam \
        /var/log/nginx \
        /var/log/webssh2 \
        /run/nginx && \
    chown -R nginx:nginx /var/log/nginx /var/cache/nginx /etc/nginx /run/nginx && \
    chown -R webssh2:webssh2 /usr/src/webssh2 /var/log/webssh2

# Copy built WebSSH2 application from builder stage
COPY --from=builder --chown=webssh2:webssh2 /build/package*.json /usr/src/webssh2/
COPY --from=builder --chown=webssh2:webssh2 /build/dist/ /usr/src/webssh2/dist/
COPY --from=builder --chown=webssh2:webssh2 /build/node_modules/ /usr/src/webssh2/node_modules/
COPY --from=builder --chown=webssh2:webssh2 /build/manifest.json /usr/src/webssh2/manifest.json

# Copy s6-overlay configuration
COPY ./rootfs/ /

# Set executable permissions on scripts and create environment export script
RUN find /etc/cont-init.d -name "*.sh" -exec chmod +x {} \; && \
    find /etc/s6-overlay -name "run" -exec chmod +x {} \; && \
    find /usr/local/bin -name "*.sh" -exec chmod +x {} \; && \
    chmod +x /etc/cont-init.d/* /usr/local/bin/* && \
    echo '#!/bin/bash' > /usr/local/bin/export-env.sh && \
    echo '# Export all WebSSH2 related environment variables (skip empty values)' >> /usr/local/bin/export-env.sh && \
    echo 'env | grep -E "^(NGINX_|WEBSSH2_|TLS_|SECURITY_|HSTS_|CSP_|FIPS_|MTLS_|DEBUG)" | while IFS= read -r line; do' >> /usr/local/bin/export-env.sh && \
    echo '  key="${line%%=*}"' >> /usr/local/bin/export-env.sh && \
    echo '  value="${line#*=}"' >> /usr/local/bin/export-env.sh && \
    echo '  # Only export if value is not empty' >> /usr/local/bin/export-env.sh && \
    echo '  if [[ -n "$value" ]]; then' >> /usr/local/bin/export-env.sh && \
    echo '    echo "export $key=\"$value\""' >> /usr/local/bin/export-env.sh && \
    echo '  fi' >> /usr/local/bin/export-env.sh && \
    echo 'done > /etc/webssh2-env' >> /usr/local/bin/export-env.sh && \
    chmod +x /usr/local/bin/export-env.sh

# Set default environment variables
ENV \
    # UBI9 FIPS Configuration
    OPENSSL_CONF=/etc/pki/tls/openssl.cnf \
    OPENSSL_FIPS=1 \
    # TLS Configuration
    TLS_MODE=self-signed \
    TLS_CERT_PATH=/etc/nginx/certs/cert.pem \
    TLS_KEY_PATH=/etc/nginx/certs/key.pem \
    TLS_CHAIN_PATH= \
    TLS_PROTOCOLS="TLSv1.2 TLSv1.3" \
    TLS_CIPHERS="ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-GCM-SHA256" \
    TLS_DH_SIZE=2048 \
    \
    # mTLS Configuration
    MTLS_ENABLED=false \
    MTLS_CA_CERT= \
    MTLS_VERIFY_DEPTH=2 \
    MTLS_CRL_PATH= \
    MTLS_OPTIONAL=false \
    \
    # FIPS Configuration
    FIPS_MODE=enabled \
    FIPS_CHECK=true \
    \
    # NGINX Configuration
    NGINX_LISTEN_PORT=443 \
    NGINX_SERVER_NAME=_ \
    NGINX_WORKER_PROCESSES=auto \
    NGINX_WORKER_CONNECTIONS=1024 \
    NGINX_KEEPALIVE_TIMEOUT=65 \
    NGINX_CLIENT_MAX_BODY_SIZE=1m \
    NGINX_PROXY_READ_TIMEOUT=3600s \
    NGINX_PROXY_SEND_TIMEOUT=3600s \
    NGINX_RATE_LIMIT=10r/s \
    NGINX_RATE_LIMIT_BURST=20 \
    NGINX_CONN_LIMIT=100 \
    NGINX_GZIP=on \
    NGINX_ACCESS_LOG=off \
    NGINX_ERROR_LOG_LEVEL=warn \
    \
    # Security Headers
    SECURITY_HEADERS=true \
    HSTS_MAX_AGE=31536000 \
    CSP_POLICY="default-src 'self'; script-src 'self' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; connect-src 'self' ws: wss:; font-src 'self'; img-src 'self' data:;" \
    \
    # WebSSH2 Configuration (Core)
    WEBSSH2_LISTEN_IP=127.0.0.1 \
    WEBSSH2_LISTEN_PORT=2222 \
    \
    # WebSSH2 SSH Configuration
    WEBSSH2_SSH_HOST= \
    WEBSSH2_SSH_PORT=22 \
    WEBSSH2_SSH_TERM=xterm-256color \
    WEBSSH2_SSH_READY_TIMEOUT=20000 \
    WEBSSH2_SSH_KEEPALIVE_INTERVAL=120000 \
    WEBSSH2_SSH_KEEPALIVE_COUNT_MAX=10 \
    WEBSSH2_SSH_ALGORITHMS_PRESET=modern \
    \
    # WebSSH2 Session Configuration
    WEBSSH2_SESSION_NAME=webssh2.sid \
    WEBSSH2_SESSION_SECRET= \
    \
    # WebSSH2 Header Configuration
    WEBSSH2_HEADER_TEXT= \
    WEBSSH2_HEADER_BACKGROUND=green \
    \
    # WebSSH2 Options
    WEBSSH2_OPTIONS_CHALLENGE_BUTTON=true \
    WEBSSH2_OPTIONS_AUTO_LOG=false \
    WEBSSH2_OPTIONS_ALLOW_REAUTH=true \
    WEBSSH2_OPTIONS_ALLOW_RECONNECT=true \
    WEBSSH2_OPTIONS_ALLOW_REPLAY=true \
    \
    # WebSSH2 CORS
    WEBSSH2_HTTP_ORIGINS= \
    \
    # Legacy support
    PORT=2222 \
    \
    # Health check
    HEALTHCHECK_INTERVAL=30 \
    HEALTHCHECK_TIMEOUT=5 \
    HEALTHCHECK_RETRIES=3

# Expose ports
EXPOSE 443

# Health check
HEALTHCHECK --interval=30s \
            --timeout=5s \
            --retries=3 \
            --start-period=10s \
            CMD /usr/local/bin/healthcheck.sh

# Use s6-overlay as entrypoint
ENTRYPOINT ["/bin/bash", "-c", "/usr/local/bin/export-env.sh && exec /init"]

# Default command (s6-overlay will handle services)
CMD []
