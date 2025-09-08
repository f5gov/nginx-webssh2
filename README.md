# NGINX + WebSSH2 with FIPS Support

A production-ready Docker container combining NGINX and WebSSH2 with FIPS 140-2 compliance, built on Red Hat UBI8.

## 📦 Installation

### Docker

```bash
# Pull the latest release
docker pull ghcr.io/f5gov/nginx-webssh2:latest

# Run the container (basic setup with auto-generated session secret)
docker run -d -p 443:443 --name nginx-webssh2 \
  ghcr.io/f5gov/nginx-webssh2:latest

# Access WebSSH2 at https://localhost
```

### Podman

```bash
# Pull the latest release
podman pull ghcr.io/f5gov/nginx-webssh2:latest

# Run the container (basic setup with auto-generated session secret)
podman run -d -p 443:443 --name nginx-webssh2 \
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
# Session Security (auto-generated if not provided)
WEBSSH2_SESSION_SECRET=""    # Random 32-byte secret generated if empty
                             # Set for production to persist sessions across restarts

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
  -e TLS_MODE=provided \
  -e TLS_CERT_CONTENT="$TLS_CERT_CONTENT" \
  -e TLS_KEY_CONTENT="$TLS_KEY_CONTENT" \
  ghcr.io/f5gov/nginx-webssh2:alpha
```

##### HashiCorp Vault
```bash
# Fetch certificates from Vault
export VAULT_ADDR="https://vault.example.com"
TLS_CERT_CONTENT=$(vault kv get -field=cert secret/webssh2/tls)
TLS_KEY_CONTENT=$(vault kv get -field=key secret/webssh2/tls)

docker run -d \
  -e TLS_MODE=provided \
  -e TLS_CERT_CONTENT="$TLS_CERT_CONTENT" \
  -e TLS_KEY_CONTENT="$TLS_KEY_CONTENT" \
  ghcr.io/f5gov/nginx-webssh2:alpha
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
  -e TLS_MODE=provided \
  -e TLS_CERT_CONTENT="$TLS_CERT_CONTENT" \
  -e TLS_KEY_CONTENT="$TLS_KEY_CONTENT" \
  ghcr.io/f5gov/nginx-webssh2:alpha
```

##### 1Password CLI
```bash
# Fetch certificates from 1Password
TLS_CERT_CONTENT=$(op item get "WebSSH2 TLS Certificate" --field cert)
TLS_KEY_CONTENT=$(op item get "WebSSH2 TLS Certificate" --field key)

docker run -d \
  -e TLS_MODE=provided \
  -e TLS_CERT_CONTENT="$TLS_CERT_CONTENT" \
  -e TLS_KEY_CONTENT="$TLS_KEY_CONTENT" \
  ghcr.io/f5gov/nginx-webssh2:alpha
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
  -e TLS_MODE=provided \
  -e TLS_CERT_PATH=/run/secrets/tls_cert \
  -e TLS_KEY_PATH=/run/secrets/tls_key \
  ghcr.io/f5gov/nginx-webssh2:alpha
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

### WebSSH2 Configuration

```bash
# Interface and Port
WEBSSH2_LISTEN_IP=127.0.0.1
WEBSSH2_LISTEN_PORT=2222

# SSH Settings
WEBSSH2_SSH_TERM=xterm-256color
WEBSSH2_SSH_ALGORITHMS_PRESET=modern
WEBSSH2_SESSION_NAME=webssh2.sid

# CORS Settings
WEBSSH2_HTTP_ORIGINS=https://webssh2.example.com:443
```

For complete configuration options, see [`.env.example`](.env.example).

## 🚀 Quick Start Examples

### Basic Deployment (Development)

```bash
# Simplest setup - auto-generates session secret
docker run -d -p 443:443 ghcr.io/f5gov/nginx-webssh2:alpha
```

### Production with Persistent Sessions

```bash
# Set explicit session secret for persistent sessions across restarts
docker run -d -p 443:443 \
  -e WEBSSH2_SESSION_SECRET="$(openssl rand -base64 32)" \
  ghcr.io/f5gov/nginx-webssh2:alpha
```

### Production with Provided Certificates

```bash
# Using volume mounts
docker run -d -p 443:443 \
  -e WEBSSH2_SESSION_SECRET="your-persistent-secret-key" \
  -e TLS_MODE=provided \
  -e FIPS_MODE=enabled \
  -v /path/to/certs:/etc/nginx/certs:ro \
  ghcr.io/f5gov/nginx-webssh2:alpha

# Using environment variables from secrets manager
docker run -d -p 443:443 \
  -e WEBSSH2_SESSION_SECRET="your-persistent-secret-key" \
  -e TLS_MODE=provided \
  -e TLS_CERT_CONTENT="$TLS_CERT_CONTENT" \
  -e TLS_KEY_CONTENT="$TLS_KEY_CONTENT" \
  -e FIPS_MODE=enabled \
  ghcr.io/f5gov/nginx-webssh2:alpha
```

### With Specific SSH Target

```bash
docker run -d -p 443:443 \
  -e WEBSSH2_SSH_HOST=ssh.example.com \
  -e WEBSSH2_SSH_PORT=22 \
  ghcr.io/f5gov/nginx-webssh2:alpha
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

- **FIPS 140-2 Compliance**: Built with Red Hat UBI8 and FIPS-certified OpenSSL
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
    image: ghcr.io/f5gov/nginx-webssh2:alpha
    ports:
      - "443:443"
    environment:
      WEBSSH2_SESSION_SECRET: "${SESSION_SECRET}"
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
    image: ghcr.io/f5gov/nginx-webssh2:alpha
    ports:
      - "443:443"
    environment:
      WEBSSH2_SESSION_SECRET: "${SESSION_SECRET}"
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
        image: ghcr.io/f5gov/nginx-webssh2:alpha
        ports:
        - containerPort: 443
        env:
        - name: WEBSSH2_SESSION_SECRET
          valueFrom:
            secretKeyRef:
              name: webssh2-secret
              key: session-secret
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
        image: ghcr.io/f5gov/nginx-webssh2:alpha
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
              key: session-secret
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
oc new-app ghcr.io/f5gov/nginx-webssh2:alpha \
  --name=nginx-webssh2 \
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
  -e NGINX_ACCESS_LOG=on \
  ghcr.io/f5gov/nginx-webssh2:alpha

# To enable WebSSH2 debug logging:
docker run -d -p 443:443 \
  -e DEBUG="webssh2:*" \
  ghcr.io/f5gov/nginx-webssh2:alpha

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
docker exec nginx-webssh2 tail -f /var/log/webssh2/webssh2.log
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
- [x] FIPS 140-2 compliance
- [x] mTLS support

## 🔗 References

- [WebSSH2 Documentation](https://github.com/billchurch/webssh2)
- [NGINX Documentation](https://nginx.org/en/docs/)
- [Red Hat UBI Documentation](https://developers.redhat.com/products/rhel/ubi)
- [FIPS 140-2 Standards](https://csrc.nist.gov/publications/detail/fips/140/2/final)
- [s6-overlay Documentation](https://github.com/just-containers/s6-overlay)

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Issues**: GitHub Issues
- **Discussions**: GitHub Discussions  
- **Security**: <billh@f5.com>

---

**⚠️ Security Notice**: This container includes FIPS 140-2 compliance features but requires a FIPS-enabled host system for full compliance. Always validate your specific compliance requirements.
