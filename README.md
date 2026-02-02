# NGINX + WebSSH2 with FIPS Support

A production-ready Docker container combining NGINX and WebSSH2 with FIPS 140-3 readiness, built on Red Hat UBI9 (Universal Base Image).

## 📦 Installation

### Docker

```bash
# Pull the latest release
docker pull ghcr.io/f5gov/nginx-webssh2:latest

# Run the container (WEBSSH2_SESSION_SECRET is required)
docker run -d -p 443:443 --name nginx-webssh2 \
  -e WEBSSH2_SESSION_SECRET="$(openssl rand -base64 32)" \
  ghcr.io/f5gov/nginx-webssh2:latest

# Access WebSSH2 at https://localhost
```

### Podman

```bash
# Pull the latest release
podman pull ghcr.io/f5gov/nginx-webssh2:latest

# Run the container (WEBSSH2_SESSION_SECRET is required)
podman run -d -p 443:443 --name nginx-webssh2 \
  -e WEBSSH2_SESSION_SECRET="$(openssl rand -base64 32)" \
  ghcr.io/f5gov/nginx-webssh2:latest

# Using podman-compose (same as docker-compose.yml)
podman-compose up -d
```

### Available Tags

- `latest` - Latest build from main branch (recommended)
- `main` - Same as latest (alternate tag)
- `alpha` - Alpha releases when version contains -alpha
- `v1.0.0`, `v1.0`, `v1` - Semantic versioning tags
- `main-<sha>` - Commit-specific builds from main branch

## ⚙️ Configuration

### Essential Environment Variables

```bash
# Session Security (REQUIRED - container will fail without it)
WEBSSH2_SESSION_SECRET=""    # REQUIRED: Must be set or container will not start
                             # Generate with: openssl rand -base64 32

# SSH Connection
WEBSSH2_SSH_HOST=""          # Empty for dynamic selection (default)
WEBSSH2_SSH_PORT=22          # SSH port (default: 22)

# Server Settings
NGINX_SERVER_NAME=localhost  # Your server hostname
NGINX_LISTEN_PORT=443        # HTTPS port (default: 443)
```

### TLS/SSL Configuration

```bash
# Certificate mode: self-signed (default), provided, letsencrypt
TLS_MODE=self-signed

# For self-signed certificates
TLS_CERT_CN=webssh2.example.com
TLS_CERT_SAN="webssh2.example.com,localhost,127.0.0.1"
```

#### Method 1: Volume Mount (Traditional)

```bash
TLS_MODE=provided
TLS_CERT_PATH=/etc/nginx/certs/cert.pem
TLS_KEY_PATH=/etc/nginx/certs/key.pem
TLS_CHAIN_PATH=/etc/nginx/certs/chain.pem  # Optional certificate chain

# Mount certificates when running container
docker run -v /path/to/certs:/etc/nginx/certs:ro ...
```

#### Method 2: Environment Variables (Secrets Manager)

```bash
TLS_MODE=provided
# Certificate content directly in environment
TLS_CERT_CONTENT="-----BEGIN CERTIFICATE-----
MIIDXTCCAkWgAwIBAgIJAK...
-----END CERTIFICATE-----"
TLS_KEY_CONTENT="-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0B...
-----END PRIVATE KEY-----"
TLS_CHAIN_CONTENT="-----BEGIN CERTIFICATE-----..."  # Optional chain
```

#### Method 3: Secrets Manager Integration Examples

##### AWS Secrets Manager
```bash
# Fetch certificates from AWS Secrets Manager
TLS_CERT_CONTENT=$(aws secretsmanager get-secret-value \
  --secret-id prod/webssh2/tls-cert \
  --query SecretString --output text)

TLS_KEY_CONTENT=$(aws secretsmanager get-secret-value \
  --secret-id prod/webssh2/tls-key \
  --query SecretString --output text)

docker run -d \
  -e WEBSSH2_SESSION_SECRET="$(openssl rand -base64 32)" \
  -e TLS_MODE=provided \
  -e TLS_CERT_CONTENT="$TLS_CERT_CONTENT" \
  -e TLS_KEY_CONTENT="$TLS_KEY_CONTENT" \
  ghcr.io/f5gov/nginx-webssh2:latest
```

##### HashiCorp Vault
```bash
# Fetch certificates from Vault
export VAULT_ADDR="https://vault.example.com"
TLS_CERT_CONTENT=$(vault kv get -field=cert secret/webssh2/tls)
TLS_KEY_CONTENT=$(vault kv get -field=key secret/webssh2/tls)

docker run -d \
  -e WEBSSH2_SESSION_SECRET="$(openssl rand -base64 32)" \
  -e TLS_MODE=provided \
  -e TLS_CERT_CONTENT="$TLS_CERT_CONTENT" \
  -e TLS_KEY_CONTENT="$TLS_KEY_CONTENT" \
  ghcr.io/f5gov/nginx-webssh2:latest
```

##### Azure Key Vault
```bash
# Fetch certificates from Azure Key Vault
TLS_CERT_CONTENT=$(az keyvault secret show \
  --vault-name MyKeyVault \
  --name webssh2-tls-cert \
  --query value -o tsv)

TLS_KEY_CONTENT=$(az keyvault secret show \
  --vault-name MyKeyVault \
  --name webssh2-tls-key \
  --query value -o tsv)

docker run -d \
  -e WEBSSH2_SESSION_SECRET="$(openssl rand -base64 32)" \
  -e TLS_MODE=provided \
  -e TLS_CERT_CONTENT="$TLS_CERT_CONTENT" \
  -e TLS_KEY_CONTENT="$TLS_KEY_CONTENT" \
  ghcr.io/f5gov/nginx-webssh2:latest
```

##### 1Password CLI
```bash
# Fetch certificates from 1Password
TLS_CERT_CONTENT=$(op item get "WebSSH2 TLS Certificate" --field cert)
TLS_KEY_CONTENT=$(op item get "WebSSH2 TLS Certificate" --field key)

docker run -d \
  -e WEBSSH2_SESSION_SECRET="$(openssl rand -base64 32)" \
  -e TLS_MODE=provided \
  -e TLS_CERT_CONTENT="$TLS_CERT_CONTENT" \
  -e TLS_KEY_CONTENT="$TLS_KEY_CONTENT" \
  ghcr.io/f5gov/nginx-webssh2:latest
```

#### Method 4: Docker/Kubernetes Native Secrets

##### Docker Secrets (Swarm Mode)
```bash
# Create secrets
echo "$CERT_CONTENT" | docker secret create webssh2-cert -
echo "$KEY_CONTENT" | docker secret create webssh2-key -

# Deploy with secrets mounted
docker service create \
  --secret source=webssh2-cert,target=/run/secrets/tls_cert \
  --secret source=webssh2-key,target=/run/secrets/tls_key \
  -e WEBSSH2_SESSION_SECRET="$(openssl rand -base64 32)" \
  -e TLS_MODE=provided \
  -e TLS_CERT_PATH=/run/secrets/tls_cert \
  -e TLS_KEY_PATH=/run/secrets/tls_key \
  ghcr.io/f5gov/nginx-webssh2:latest
```

##### Kubernetes Secrets
```yaml
# Create secret
kubectl create secret tls webssh2-tls \
  --cert=path/to/cert.pem \
  --key=path/to/key.pem

# Use in deployment
apiVersion: v1
kind: Deployment
spec:
  template:
    spec:
      containers:
      - name: nginx-webssh2
        env:
        - name: TLS_MODE
          value: "provided"
        - name: TLS_CERT_PATH
          value: "/etc/tls/tls.crt"
        - name: TLS_KEY_PATH
          value: "/etc/tls/tls.key"
        volumeMounts:
        - name: tls-secret
          mountPath: /etc/tls
          readOnly: true
      volumes:
      - name: tls-secret
        secret:
          secretName: webssh2-tls
```

### Security Configuration

```bash
# FIPS Mode
FIPS_MODE=enabled            # enabled or disabled
FIPS_CHECK=true              # Strict FIPS validation

# Mutual TLS (mTLS)
MTLS_ENABLED=false           # Enable client certificates
MTLS_CA_CERT=/etc/nginx/certs/ca.pem
MTLS_VERIFY_DEPTH=2

# Rate Limiting
NGINX_RATE_LIMIT=10r/s       # Request rate limit
NGINX_RATE_LIMIT_BURST=20    # Burst size
NGINX_CONN_LIMIT=100         # Connection limit per IP
```

### NGINX Performance Tuning

```bash
# Worker Configuration
NGINX_WORKER_PROCESSES=auto      # Number of worker processes (default: auto)
NGINX_WORKER_CONNECTIONS=1024    # Max connections per worker (default: 1024)
NGINX_KEEPALIVE_TIMEOUT=65       # Keepalive timeout in seconds (default: 65)

# Client Settings
NGINX_CLIENT_MAX_BODY_SIZE=1m    # Max request body size (default: 1m)

# Proxy Timeouts
NGINX_PROXY_READ_TIMEOUT=3600s   # Proxy read timeout (default: 3600s)
NGINX_PROXY_SEND_TIMEOUT=3600s   # Proxy send timeout (default: 3600s)

# Network Configuration
NGINX_LISTEN_IPV6=true           # Enable IPv6 support (default: true)
                                 # Set to false if host doesn't support IPv6

# Compression
NGINX_GZIP=on                    # Enable gzip compression (default: on)

# Logging
NGINX_ACCESS_LOG=off             # Enable access logs (default: off)
NGINX_ERROR_LOG_LEVEL=warn       # Error log level (default: warn)
```

**Note**: If you encounter the error `socket() [::]:443 failed (97: Address family not supported by protocol)`, set `NGINX_LISTEN_IPV6=false` to disable IPv6.

### WebSSH2 Configuration

#### Listen Settings

```bash
WEBSSH2_LISTEN_IP=127.0.0.1      # IP address to listen on (default: 127.0.0.1)
WEBSSH2_LISTEN_PORT=2222         # Port to listen on (default: 2222)
PORT=2222                        # Legacy port variable (maps to WEBSSH2_LISTEN_PORT)
```

#### SSH Connection Settings

```bash
# Target SSH Server
WEBSSH2_SSH_HOST=                # Target SSH host (empty for dynamic selection)
WEBSSH2_SSH_PORT=22              # Target SSH port (default: 22)
WEBSSH2_SSH_TERM=xterm-256color  # Terminal emulation type (default: xterm-256color)

# Local Binding (optional)
WEBSSH2_SSH_LOCAL_ADDRESS=       # Local address to bind for SSH connection
WEBSSH2_SSH_LOCAL_PORT=          # Local port to bind for SSH connection

# Timeouts and Keepalive
WEBSSH2_SSH_READY_TIMEOUT=20000         # SSH connection ready timeout in ms (default: 20000)
WEBSSH2_SSH_KEEPALIVE_INTERVAL=120000   # Keepalive interval in ms (default: 120000)
WEBSSH2_SSH_KEEPALIVE_COUNT_MAX=10      # Max keepalive count before disconnect (default: 10)
```

#### SSH Algorithm Configuration

```bash
# Algorithm Preset (recommended approach)
WEBSSH2_SSH_ALGORITHMS_PRESET=modern    # Preset: modern, legacy, or strict (default: modern)

# Custom Algorithms (override preset - comma-separated or JSON array)
WEBSSH2_SSH_ALGORITHMS_CIPHER=          # Cipher algorithms (e.g., aes256-gcm@openssh.com,aes128-gcm@openssh.com)
WEBSSH2_SSH_ALGORITHMS_KEX=             # Key exchange algorithms
WEBSSH2_SSH_ALGORITHMS_HMAC=            # HMAC algorithms
WEBSSH2_SSH_ALGORITHMS_COMPRESS=        # Compression algorithms
WEBSSH2_SSH_ALGORITHMS_SERVER_HOST_KEY= # Server host key algorithms
```

**Algorithm Presets:**
- `modern` - AES-GCM, ECDH, SHA2, modern ciphers (recommended)
- `legacy` - AES-CBC, DH groups, SHA1, older ciphers (for compatibility)
- `strict` - Most restrictive, ECDH only, AES256-GCM only (highest security)

#### SSH Authentication

```bash
# Pre-configured Credentials (optional - for kiosk/fixed-target deployments)
WEBSSH2_USER_NAME=               # Pre-configured SSH username
WEBSSH2_USER_PASSWORD=           # Pre-configured SSH password
WEBSSH2_USER_PRIVATE_KEY=        # Pre-configured SSH private key (PEM format)
WEBSSH2_USER_PASSPHRASE=         # Passphrase for encrypted private key

# Allowed Authentication Methods (comma-separated)
WEBSSH2_AUTH_ALLOWED=password,keyboard-interactive,publickey
```

#### SSH Behavior

```bash
WEBSSH2_SSH_ALWAYS_SEND_KEYBOARD_INTERACTIVE=false  # Always send keyboard-interactive prompts
WEBSSH2_SSH_DISABLE_INTERACTIVE_AUTH=false          # Disable interactive authentication
WEBSSH2_SSH_ENV_ALLOWLIST=                          # Environment variables to pass to SSH (comma-separated)
WEBSSH2_SSH_ALLOWED_SUBNETS=                        # CIDR subnets allowed for SSH (comma-separated)
WEBSSH2_SSH_MAX_EXEC_OUTPUT_BYTES=10485760          # Max bytes for command execution (default: 10MB)
WEBSSH2_SSH_OUTPUT_RATE_LIMIT_BYTES_PER_SEC=0       # Output rate limit (0 = unlimited)
WEBSSH2_SSH_SOCKET_HIGH_WATER_MARK=16384            # Socket high water mark (default: 16KB)
```

#### Session Configuration

```bash
WEBSSH2_SESSION_SECRET=          # REQUIRED: Session encryption secret (generate with: openssl rand -base64 32)
WEBSSH2_SESSION_NAME=webssh2.sid # Session cookie name (default: webssh2.sid)
```

#### UI Header Configuration

```bash
WEBSSH2_HEADER_TEXT=             # Custom header text displayed in terminal
WEBSSH2_HEADER_BACKGROUND=green  # Header background color (default: green)
```

#### UI Options

```bash
WEBSSH2_OPTIONS_CHALLENGE_BUTTON=true   # Show challenge/response button (default: true)
WEBSSH2_OPTIONS_AUTO_LOG=false          # Automatically log SSH sessions (default: false)
WEBSSH2_OPTIONS_ALLOW_REAUTH=true       # Allow re-authentication during session (default: true)
WEBSSH2_OPTIONS_ALLOW_RECONNECT=true    # Allow reconnection to SSH server (default: true)
WEBSSH2_OPTIONS_ALLOW_REPLAY=true       # Allow session replay (default: true)
WEBSSH2_OPTIONS_REPLAY_CRLF=false       # Convert LF to CRLF during replay (default: false)
```

#### CORS Configuration

```bash
WEBSSH2_HTTP_ORIGINS=            # Allowed CORS origins (comma-separated or JSON array)
                                 # Example: https://webssh2.example.com:443,https://backup.example.com
                                 # Default: *:* (all origins - restrict in production)
```

### SSO Configuration

```bash
# Enable SSO for enterprise authentication
WEBSSH2_SSO_ENABLED=false                    # Enable SSO authentication (default: false)
WEBSSH2_SSO_CSRF_PROTECTION=false            # Enable CSRF protection for SSO (default: false)
WEBSSH2_SSO_TRUSTED_PROXIES=                 # Trusted proxy IPs (comma-separated, bypasses CSRF)

# Header Mapping for SSO Credentials
WEBSSH2_SSO_HEADER_USERNAME=x-apm-username   # HTTP header for SSO username
WEBSSH2_SSO_HEADER_PASSWORD=x-apm-password   # HTTP header for SSO password
WEBSSH2_SSO_HEADER_SESSION=x-apm-session     # HTTP header for SSO session
```

### WebSSH2 Logging Configuration

```bash
# General Logging
WEBSSH2_LOGGING_LEVEL=info               # Minimum log level: debug, info, warn, error (default: info)
WEBSSH2_LOGGING_STDOUT_ENABLED=true      # Enable logging to stdout (default: true)
WEBSSH2_LOGGING_STDOUT_MIN_LEVEL=        # Minimum stdout log level (inherits from LOGGING_LEVEL)

# Log Sampling (optional - for high-volume environments)
WEBSSH2_LOGGING_SAMPLING_DEFAULT_RATE=   # Default sampling rate 0-1 (e.g., 0.1 = 10%)
WEBSSH2_LOGGING_SAMPLING_RULES=          # JSON array: [{"target": "event-name", "sampleRate": 0.1}]

# Rate Limiting (optional)
WEBSSH2_LOGGING_RATE_LIMIT_RULES=        # JSON array: [{"target": "*", "limit": 100, "intervalMs": 60000}]

# Debug Logging
DEBUG=                                   # Debug namespace filter (e.g., webssh2:*, socket,ssh,config)
```

### Syslog Configuration

```bash
# Syslog Transport
WEBSSH2_LOGGING_SYSLOG_ENABLED=false     # Enable syslog logging (default: false)
WEBSSH2_LOGGING_SYSLOG_HOST=             # Syslog server hostname (required if enabled)
WEBSSH2_LOGGING_SYSLOG_PORT=             # Syslog server port (required if enabled)
WEBSSH2_LOGGING_SYSLOG_APP_NAME=webssh2  # Application name for syslog (default: webssh2)
WEBSSH2_LOGGING_SYSLOG_ENTERPRISE_ID=    # Enterprise ID for structured syslog
WEBSSH2_LOGGING_SYSLOG_BUFFER_SIZE=      # Buffer size for syslog messages
WEBSSH2_LOGGING_SYSLOG_FLUSH_INTERVAL_MS= # Flush interval in milliseconds
WEBSSH2_LOGGING_SYSLOG_INCLUDE_JSON=     # Include JSON structured data in syslog

# Syslog TLS (for secure syslog transport)
WEBSSH2_LOGGING_SYSLOG_TLS_ENABLED=false           # Enable TLS for syslog
WEBSSH2_LOGGING_SYSLOG_TLS_CA_FILE=                # CA certificate file for syslog TLS
WEBSSH2_LOGGING_SYSLOG_TLS_CERT_FILE=              # Client certificate file
WEBSSH2_LOGGING_SYSLOG_TLS_KEY_FILE=               # Client key file
WEBSSH2_LOGGING_SYSLOG_TLS_REJECT_UNAUTHORIZED=    # Reject unauthorized syslog TLS certs
```

### Environment Variable Parsing Notes

**Array Variables** accept either format:
- Comma-separated: `value1,value2,value3`
- JSON array: `["value1","value2","value3"]`

**Boolean Variables** accept:
- `true` or `1` for true
- Any other value for false

For additional details, see the upstream [WebSSH2 configuration reference](https://github.com/billchurch/webssh2/blob/main/DOCS/configuration/ENVIRONMENT-VARIABLES.md).

## 🚀 Quick Start Examples

### Basic Deployment (Development)

```bash
# Simplest setup - session secret is required
docker run -d -p 443:443 \
  -e WEBSSH2_SESSION_SECRET="$(openssl rand -base64 32)" \
  ghcr.io/f5gov/nginx-webssh2:latest
```

### Production with Persistent Sessions

```bash
# Use a persistent secret for sessions to survive container restarts
# Store this value securely and reuse it across deployments
docker run -d -p 443:443 \
  -e WEBSSH2_SESSION_SECRET="your-persistent-secret-here" \
  ghcr.io/f5gov/nginx-webssh2:latest
```

### Production with Provided Certificates

```bash
# Using volume mounts
docker run -d -p 443:443 \
  -e WEBSSH2_SESSION_SECRET="$(openssl rand -base64 32)" \
  -e TLS_MODE=provided \
  -e FIPS_MODE=enabled \
  -v /path/to/certs:/etc/nginx/certs:ro \
  ghcr.io/f5gov/nginx-webssh2:latest

# Using environment variables from secrets manager
docker run -d -p 443:443 \
  -e WEBSSH2_SESSION_SECRET="$(openssl rand -base64 32)" \
  -e TLS_MODE=provided \
  -e TLS_CERT_CONTENT="$TLS_CERT_CONTENT" \
  -e TLS_KEY_CONTENT="$TLS_KEY_CONTENT" \
  -e FIPS_MODE=enabled \
  ghcr.io/f5gov/nginx-webssh2:latest
```

### With Specific SSH Target

```bash
docker run -d -p 443:443 \
  -e WEBSSH2_SESSION_SECRET="$(openssl rand -base64 32)" \
  -e WEBSSH2_SSH_HOST=ssh.example.com \
  -e WEBSSH2_SSH_PORT=22 \
  ghcr.io/f5gov/nginx-webssh2:latest
```

## 🏗️ Architecture

```ascii
┌─────────────────┐    ┌──────────────┐    ┌──────────────┐
│   Browser       │───▶│    NGINX     │───▶│   WebSSH2    │
│   (Client)      │    │ (Proxy+TLS)  │    │  (Node.js)   │
└─────────────────┘    └──────────────┘    └──────────────┘
                                                  │
                                                  ▼
                                           ┌──────────────┐
                                           │   SSH Host   │
                                           │   (Target)   │
                                           └──────────────┘
```

## ✨ Features

### 🔒 Security

- **FIPS 140-3 Ready**: Built with Red Hat UBI9 and OpenSSL 3.2.2 with FIPS provider support
- **Mutual TLS (mTLS)**: Optional client certificate authentication
- **Security Headers**: HSTS, CSP, X-Frame-Options, and more
- **Rate Limiting**: Configurable request and connection limits
- **Non-root Execution**: Services run as unprivileged users

### 🌐 SSL/TLS

- **Multiple Certificate Modes**: Self-signed, provided certificates, or Let's Encrypt
- **FIPS-Approved Ciphers**: TLS 1.2/1.3 with FIPS-compliant cipher suites
- **Perfect Forward Secrecy**: Elliptic curve and RSA key exchange
- **Certificate Validation**: Automatic certificate health checks

### 🚀 Performance

- **s6-overlay**: Reliable process supervision
- **WebSocket Optimization**: Optimized for real-time SSH connections
- **Compression**: Gzip compression for static assets
- **Connection Pooling**: Efficient backend connection management

### ⚙️ Advanced Configuration

- **Environment-Based**: Complete configuration via environment variables
- **Hot Reloading**: Configuration updates without container restart
- **Health Checks**: Comprehensive container and service health monitoring
- **Logging**: Structured logging with configurable levels

## 🏃 Deployment

### Docker Compose

```yaml
version: '3.8'

services:
  nginx-webssh2:
    image: ghcr.io/f5gov/nginx-webssh2:latest
    ports:
      - "443:443"
    environment:
      WEBSSH2_SESSION_SECRET: "${SESSION_SECRET}"  # REQUIRED: Set in .env file
      TLS_MODE: provided
      FIPS_MODE: enabled
    volumes:
      - ./certs:/etc/nginx/certs:ro
    restart: unless-stopped
```

### Podman Compose

```yaml
# podman-compose.yml - Same format as docker-compose.yml
version: '3.8'

services:
  nginx-webssh2:
    image: ghcr.io/f5gov/nginx-webssh2:latest
    ports:
      - "443:443"
    environment:
      WEBSSH2_SESSION_SECRET: "${SESSION_SECRET}"  # REQUIRED: Set in .env file
      TLS_MODE: provided
      FIPS_MODE: enabled
    volumes:
      - ./certs:/etc/nginx/certs:ro
    restart: unless-stopped
    security_opt:
      - label=disable  # SELinux context for rootless podman
```

```bash
# Install podman-compose if needed
pip3 install podman-compose

# Run with podman-compose
podman-compose up -d

# Or use podman play kube (generate from compose)
podman-compose generate-kube > nginx-webssh2.yaml
podman play kube nginx-webssh2.yaml

# Systemd integration (rootless)
podman generate systemd --new --name nginx-webssh2 \
  > ~/.config/systemd/user/nginx-webssh2.service
systemctl --user enable nginx-webssh2.service
systemctl --user start nginx-webssh2.service
```

### Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-webssh2
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx-webssh2
  template:
    metadata:
      labels:
        app: nginx-webssh2
    spec:
      containers:
      - name: nginx-webssh2
        image: ghcr.io/f5gov/nginx-webssh2:latest
        ports:
        - containerPort: 443
        env:
        - name: WEBSSH2_SESSION_SECRET
          valueFrom:
            secretKeyRef:
              name: webssh2-secret
              key: session-secret  # REQUIRED: Must be set
        livenessProbe:
          exec:
            command:
            - /usr/local/bin/healthcheck.sh
          initialDelaySeconds: 30
          periodSeconds: 30
```

### OpenShift

```yaml
# Create OpenShift deployment with proper security context
apiVersion: apps.openshift.io/v1
kind: DeploymentConfig
metadata:
  name: nginx-webssh2
  namespace: webssh2-project
spec:
  replicas: 3
  selector:
    app: nginx-webssh2
  template:
    metadata:
      labels:
        app: nginx-webssh2
    spec:
      containers:
      - name: nginx-webssh2
        image: ghcr.io/f5gov/nginx-webssh2:latest
        ports:
        - containerPort: 443
          protocol: TCP
        env:
        - name: TLS_MODE
          value: "provided"
        - name: FIPS_MODE
          value: "enabled"
        - name: WEBSSH2_SESSION_SECRET
          valueFrom:
            secretKeyRef:
              name: webssh2-secret
              key: session-secret  # REQUIRED: Must be set
        volumeMounts:
        - name: tls-certs
          mountPath: /etc/nginx/certs
          readOnly: true
        resources:
          limits:
            memory: "512Mi"
            cpu: "1000m"
          requests:
            memory: "256Mi"
            cpu: "500m"
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          runAsNonRoot: true
        livenessProbe:
          exec:
            command:
            - /usr/local/bin/healthcheck.sh
          initialDelaySeconds: 30
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /health
            port: 443
            scheme: HTTPS
          initialDelaySeconds: 10
          periodSeconds: 10
      volumes:
      - name: tls-certs
        secret:
          secretName: webssh2-tls
      serviceAccountName: nginx-webssh2
      securityContext:
        fsGroup: 1001
        supplementalGroups: [1001]
---
# Service
apiVersion: v1
kind: Service
metadata:
  name: nginx-webssh2
spec:
  selector:
    app: nginx-webssh2
  ports:
  - name: https
    port: 443
    targetPort: 443
  type: ClusterIP
---
# Route with TLS termination
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: nginx-webssh2
spec:
  host: webssh2.apps.example.com
  to:
    kind: Service
    name: nginx-webssh2
  port:
    targetPort: https
  tls:
    termination: passthrough
    insecureEdgeTerminationPolicy: Redirect
```

#### OpenShift CLI Commands

```bash
# Create new project
oc new-project webssh2-project

# Create secrets
oc create secret tls webssh2-tls \
  --cert=path/to/cert.pem \
  --key=path/to/key.pem

oc create secret generic webssh2-secret \
  --from-literal=session-secret="$(openssl rand -base64 32)"

# Deploy using oc new-app
oc new-app ghcr.io/f5gov/nginx-webssh2:latest \
  --name=nginx-webssh2 \
  -e WEBSSH2_SESSION_SECRET="$(openssl rand -base64 32)" \
  -e TLS_MODE=provided \
  -e FIPS_MODE=enabled

# Set security context constraints (if needed)
oc adm policy add-scc-to-user anyuid -z default

# Expose the service
oc expose svc/nginx-webssh2 --port=443

# Scale deployment
oc scale --replicas=3 dc/nginx-webssh2
```

## 🔍 Monitoring & Health

### Health Check Endpoint

```bash
# HTTPS health check
curl -k https://localhost/health

# Container health check
docker exec nginx-webssh2 /usr/local/bin/healthcheck.sh
```

### Logging

#### Enable Logging

```bash
# NGINX access logs are disabled by default for performance
# To enable NGINX access logging:
docker run -d -p 443:443 \
  -e WEBSSH2_SESSION_SECRET="$(openssl rand -base64 32)" \
  -e NGINX_ACCESS_LOG=on \
  ghcr.io/f5gov/nginx-webssh2:latest

# To enable WebSSH2 debug logging:
docker run -d -p 443:443 \
  -e WEBSSH2_SESSION_SECRET="$(openssl rand -base64 32)" \
  -e DEBUG="webssh2:*" \
  ghcr.io/f5gov/nginx-webssh2:latest

# Or enable specific debug namespaces:
# DEBUG="webssh2:socket,webssh2:ssh,webssh2:config"
```

#### View Logs

```bash
# View container logs (includes all service output)
docker logs nginx-webssh2

# NGINX error logs (always enabled)
docker exec nginx-webssh2 tail -f /var/log/nginx/error.log

# NGINX access logs (only when NGINX_ACCESS_LOG=on)
docker exec nginx-webssh2 tail -f /var/log/nginx/access.log

# WebSSH2 logs (debug output when DEBUG is set)
docker exec nginx-webssh2 tail -f /var/log/webssh2/current
```

#### Logging Configuration

```bash
# Environment variables for logging control
NGINX_ACCESS_LOG=off         # 'on' or 'off' (default: off)
NGINX_ERROR_LOG_LEVEL=warn   # debug, info, notice, warn, error, crit
DEBUG=                       # WebSSH2 debug namespaces (empty = minimal logging)
```

## 🛠️ Building from Source

For detailed build instructions, see [docs/BUILD.md](docs/BUILD.md).


## 🔒 Security Considerations

### FIPS Compliance

- **Host Requirements**: Container must run on FIPS-enabled host for full compliance
- **Kernel Support**: FIPS mode requires compatible host kernel
- **Certificate Validation**: All certificates validated against FIPS standards
- **Algorithm Restrictions**: Only FIPS-approved ciphers and protocols

### Network Security

```bash
# Restrict SSH access
WEBSSH2_SSH_HOST=internal-ssh-gateway.example.com

# Enable mTLS
MTLS_ENABLED=true
MTLS_CA_CERT=/etc/nginx/certs/ca.pem

# CORS restrictions
WEBSSH2_HTTP_ORIGINS=https://webssh2.example.com:443
```

### Secrets Management

```bash
# Use Docker secrets or Kubernetes secrets
WEBSSH2_SESSION_SECRET_FILE=/run/secrets/session_secret
TLS_CERT_PATH=/run/secrets/tls_cert
TLS_KEY_PATH=/run/secrets/tls_key
```


## 🤝 Contributing

See [docs/BUILD.md](docs/BUILD.md) for development setup and testing requirements.

## 🚢 CI/CD & Container Registry

> 📖 **Full documentation**: See [GITHUB_WORKFLOW.md](GITHUB_WORKFLOW.md) for detailed CI/CD setup

### Multi-Architecture Support

Images are built for:
- `linux/amd64` - Intel/AMD 64-bit
- `linux/arm64` - ARM 64-bit (Apple Silicon, AWS Graviton)

### Automated Pipeline

Every push triggers:
1. Multi-architecture Docker build
2. Vulnerability scanning with Trivy
3. Container attestation generation
4. Automatic push to GitHub Container Registry

## 📋 Roadmap

- [ ] Let's Encrypt integration
- [ ] OAuth2/OIDC authentication
- [ ] Prometheus metrics
- [x] ARM64 support (multi-arch builds)
- [x] GitHub Container Registry publishing
- [x] FIPS 140-3 readiness (requires FIPS-enabled host)
- [x] mTLS support

## 🔄 Migration from UBI8

If you're upgrading from the previous UBI8-based version:

### Key Changes
- **Base Image**: Upgraded from UBI8 to UBI9 for extended support
- **OpenSSL**: Upgraded from 1.1.x to 3.2.2 with provider-based architecture
- **Performance**: ~6% smaller image, 21% faster startup, 4.5% less memory usage
- **FIPS**: Now targets FIPS 140-3 readiness (from 140-2)

### Migration Steps
1. **For Development**: Add `FIPS_CHECK=false` if not on FIPS-enabled host
2. **For Production**: Ensure your host supports FIPS if compliance is required
3. **No Breaking Changes**: All existing environment variables and configurations remain compatible

See [docs/UBI9-upgrade.md](docs/UBI9-upgrade.md) for detailed technical information.

## 🔗 References

- [WebSSH2 Documentation](https://github.com/billchurch/webssh2)
- [NGINX Documentation](https://nginx.org/en/docs/)
- [Red Hat UBI Documentation](https://developers.redhat.com/products/rhel/ubi)
- [FIPS 140-3 Standards](https://csrc.nist.gov/projects/cryptographic-module-validation-program)
- [s6-overlay Documentation](https://github.com/just-containers/s6-overlay)

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Issues**: GitHub Issues
- **Discussions**: GitHub Discussions  
- **Security**: <bill@f5.com>

---

**⚠️ Security Notice**: This container includes FIPS 140-3 readiness features with OpenSSL 3.2.2 but requires a FIPS-enabled host system for full compliance. Set `FIPS_CHECK=false` for non-FIPS development environments. Always validate your specific compliance requirements.
