# NGINX + WebSSH2 with FIPS Support

A production-ready Docker container combining NGINX and WebSSH2 with FIPS 140-2 compliance, built on Red Hat UBI8.

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

### ⚙️ Configuration

- **Environment-Based**: Complete configuration via environment variables
- **Hot Reloading**: Configuration updates without container restart
- **Health Checks**: Comprehensive container and service health monitoring
- **Logging**: Structured logging with configurable levels

## 🚀 Quick Start

### Using Pre-built Container from GitHub Container Registry

```bash
# Pull the latest image (no authentication required for public images)
docker pull ghcr.io/f5gov/nginx-webssh2:latest

# Run with default configuration
docker run -d -p 443:443 --name nginx-webssh2 \
  -e WEBSSH2_SESSION_SECRET="your-secret-key-change-in-production" \
  ghcr.io/f5gov/nginx-webssh2:latest

# Or use specific version
docker pull ghcr.io/f5gov/nginx-webssh2:v1.0.0
```

### Building from Source

#### Prerequisites

- Docker and Docker Compose
- Access to Red Hat container registry (registry.access.redhat.com)

#### 1. Clone Repository with Submodules

```bash
git clone --recursive https://github.com/f5gov/nginx-webssh2.git
cd nginx-webssh2

# If you already cloned without submodules
git submodule update --init --recursive
```

#### 2. Configure Environment

```bash
cp .env.example .env
# Edit .env with your settings
```

#### 3. Build and Run

```bash
# Build using docker-compose
docker-compose up --build

# Or build manually
docker build -t nginx-webssh2:latest .
```

#### 4. Access WebSSH2

- **HTTPS**: <https://localhost> (will use self-signed certificate)
- **Health Check**: <https://localhost/health>

## 📁 Repository Structure

```ascii
nginx-webssh2/
├── .github/
│   └── workflows/
│       └── publish.yml                    # GitHub Actions CI/CD workflow
├── GITHUB_WORKFLOW.md                     # Detailed workflow documentation
├── Dockerfile                              # Multi-stage container build
├── docker-compose.yml                      # Development/testing compose
├── .env.example                            # Environment configuration template
├── README.md                              # This file
├── .gitignore                             # Git ignore patterns
├── .gitmodules                            # Submodule configuration (webssh2)
├── webssh2/                               # WebSSH2 submodule (newmain branch)
├── rootfs/                                # Container filesystem overlay
│   ├── etc/
│   │   ├── nginx/                         # NGINX configuration
│   │   │   ├── nginx.conf.template        # Main NGINX config
│   │   │   ├── conf.d/
│   │   │   │   └── webssh2.conf.template  # WebSSH2 proxy config
│   │   │   └── snippets/
│   │   │       ├── ssl-params.conf        # SSL/TLS parameters
│   │   │       ├── security-headers.conf   # Security headers
│   │   │       └── mtls.conf.template     # mTLS configuration
│   │   ├── s6-overlay/                    # Process supervision
│   │   │   └── s6-rc.d/                   # Service definitions
│   │   │       ├── nginx/                 # NGINX service
│   │   │       └── webssh2/               # WebSSH2 service
│   │   └── cont-init.d/                   # Initialization scripts
│   │       ├── 10-check-fips.sh          # FIPS validation
│   │       ├── 20-setup-tls.sh           # Certificate setup
│   │       ├── 30-configure-nginx.sh     # NGINX configuration
│   │       └── 40-configure-webssh2.sh   # WebSSH2 configuration
│   └── usr/local/bin/                     # Utility scripts
│       ├── generate-self-signed-cert.sh   # Certificate generation
│       └── healthcheck.sh                 # Health check script
└── tests/                                 # Test scripts
    ├── test-fips.sh                      # FIPS compliance tests
    ├── test-tls.sh                       # TLS configuration tests
    └── test-websocket.sh                 # WebSocket connectivity tests
```

## ⚙️ Configuration Parameters

### Environment Variables

#### TLS Configuration

```bash
# Certificate mode: self-signed, provided, letsencrypt
TLS_MODE=self-signed

# Certificate paths (for provided mode)
TLS_CERT_PATH=/etc/nginx/certs/cert.pem
TLS_KEY_PATH=/etc/nginx/certs/key.pem

# Or certificate content via environment
TLS_CERT_CONTENT="-----BEGIN CERTIFICATE-----..."
TLS_KEY_CONTENT="-----BEGIN PRIVATE KEY-----..."

# TLS protocols and ciphers
TLS_PROTOCOLS="TLSv1.2 TLSv1.3"
TLS_CIPHERS="ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256"
```

#### mTLS Configuration

```bash
# Enable mutual TLS
MTLS_ENABLED=true
MTLS_CA_CERT=/etc/nginx/certs/ca.pem
MTLS_VERIFY_DEPTH=2
MTLS_OPTIONAL=false  # true for optional client certs
```

#### FIPS Configuration

```bash
# FIPS mode: enabled, disabled
FIPS_MODE=enabled
FIPS_CHECK=true  # Strict FIPS validation
```

#### NGINX Configuration

```bash
# Server settings
NGINX_LISTEN_PORT=443
NGINX_SERVER_NAME=webssh2.example.com
NGINX_WORKER_PROCESSES=auto

# Security settings
NGINX_RATE_LIMIT=10r/s
NGINX_RATE_LIMIT_BURST=20
NGINX_CONN_LIMIT=100
```

#### WebSSH2 Configuration

```bash
# Core settings
WEBSSH2_LISTEN_IP=127.0.0.1
WEBSSH2_LISTEN_PORT=2222

# SSH settings
WEBSSH2_SSH_HOST=""  # Empty for dynamic selection
WEBSSH2_SSH_PORT=22
WEBSSH2_SSH_TERM=xterm-256color
WEBSSH2_SSH_ALGORITHMS_PRESET=modern

# Session security
WEBSSH2_SESSION_SECRET="your-secret-key"
WEBSSH2_SESSION_NAME=webssh2.sid
```

For complete configuration options, see [`.env.example`](.env.example).

### Certificate Management

#### Self-Signed Certificates

```bash
TLS_MODE=self-signed
TLS_CERT_CN=webssh2.example.com
TLS_CERT_SAN="webssh2.example.com,localhost,127.0.0.1"
```

#### Provided Certificates

```bash
TLS_MODE=provided

# Method 1: File paths (via volume mount)
TLS_CERT_PATH=/etc/nginx/certs/cert.pem
TLS_KEY_PATH=/etc/nginx/certs/key.pem

# Method 2: Environment variables
TLS_CERT_CONTENT="-----BEGIN CERTIFICATE-----
MIIDXTCCAkWgAwIBAgIJAK..."
TLS_KEY_CONTENT="-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC..."
```

#### Let's Encrypt (Future)

```bash
TLS_MODE=letsencrypt
TLS_ACME_EMAIL=admin@example.com
TLS_ACME_STAGING=false
```

## 🏃 Deployment

### Production Deployment

#### Docker Compose Production

```yaml
version: '3.8'

services:
  nginx-webssh2:
    image: nginx-webssh2:latest
    ports:
      - "443:443"
    environment:
      # Production security settings
      TLS_MODE: provided
      FIPS_MODE: enabled
      FIPS_CHECK: true
      MTLS_ENABLED: true
      
      # Performance settings
      NGINX_WORKER_PROCESSES: auto
      NGINX_RATE_LIMIT: 50r/s
      NGINX_CONN_LIMIT: 500
      
      # Security
      WEBSSH2_SESSION_SECRET: "${SESSION_SECRET}"
      HSTS_MAX_AGE: 31536000
      
    volumes:
      - ./certs:/etc/nginx/certs:ro
      - ./ca-certs:/etc/nginx/ca-certs:ro
      - nginx-logs:/var/log
    
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true

volumes:
  nginx-logs:
```

#### Kubernetes Deployment

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
        image: nginx-webssh2:latest
        ports:
        - containerPort: 443
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
          readOnlyRootFilesystem: true
          runAsNonRoot: true
        livenessProbe:
          exec:
            command:
            - /usr/local/bin/healthcheck.sh
          initialDelaySeconds: 30
          periodSeconds: 30
      volumes:
      - name: tls-certs
        secret:
          secretName: nginx-webssh2-tls
```

### Security Considerations

#### FIPS Compliance

- **Host Requirements**: Container must run on FIPS-enabled host for full compliance
- **Kernel Support**: FIPS mode requires compatible host kernel
- **Certificate Validation**: All certificates validated against FIPS standards
- **Algorithm Restrictions**: Only FIPS-approved ciphers and protocols

#### Network Security

```bash
# Restrict SSH access
WEBSSH2_SSH_HOST=internal-ssh-gateway.example.com

# Enable mTLS
MTLS_ENABLED=true
MTLS_CA_CERT=/etc/nginx/certs/ca.pem

# CORS restrictions
WEBSSH2_HTTP_ORIGINS=https://webssh2.example.com:443
```

#### Secrets Management

```bash
# Use Docker secrets or Kubernetes secrets
WEBSSH2_SESSION_SECRET_FILE=/run/secrets/session_secret
TLS_CERT_PATH=/run/secrets/tls_cert
TLS_KEY_PATH=/run/secrets/tls_key
```

## 🔍 Monitoring & Logging

### Health Checks

The container includes comprehensive health checks:

```bash
# Manual health check
docker exec nginx-webssh2 /usr/local/bin/healthcheck.sh

# Health check output
=== Health Check Results ===
[OK] NGINX process is running
[OK] WebSSH2 process is running  
[OK] NGINX HTTPS endpoint responding
[OK] WebSSH2 listening on 127.0.0.1:2222
[OK] TLS certificate is valid
[OK] Disk usage: 45%
[OK] Memory usage: 67%
[OK] FIPS mode is enabled

Overall Status: HEALTHY
```

### Logging

#### Log Locations

```bash
# NGINX logs
/var/log/nginx/access.log
/var/log/nginx/error.log

# WebSSH2 logs  
/var/log/webssh2/webssh2.log

# System logs
/var/log/messages
```

#### Log Configuration

```bash
# NGINX logging
NGINX_ACCESS_LOG=on
NGINX_ERROR_LOG_LEVEL=warn

# WebSSH2 debugging
DEBUG=socket,ssh,config
```

#### Centralized Logging

```yaml
# Fluentd/ELK integration
logging:
  driver: fluentd
  options:
    fluentd-address: localhost:24224
    tag: nginx-webssh2
```

## 🧪 Testing

### Build and Test

```bash
# Build container
docker build -t nginx-webssh2:test .

# Run tests
./tests/test-fips.sh
./tests/test-tls.sh
./tests/test-websocket.sh

# Integration test
docker-compose -f docker-compose.yml up --build -d
curl -k https://localhost/health
```

### FIPS Validation

```bash
# Verify FIPS mode
docker exec nginx-webssh2 cat /proc/sys/crypto/fips_enabled

# Check OpenSSL FIPS
docker exec nginx-webssh2 openssl version -a

# Test cipher suites
openssl s_client -connect localhost:443 -cipher 'FIPS'
```

### Load Testing

```bash
# WebSocket connections
wscat -c wss://localhost/socket.io/?transport=websocket

# HTTP load test
ab -n 1000 -c 10 -k https://localhost/health
```

## 🛠️ Development

### Local Development

```bash
# Clone repositories
git clone https://github.com/billchurch/webssh2.git
git clone https://github.com/your-org/nginx-webssh2.git

# Build for development
cd nginx-webssh2
docker-compose up --build

# Enable debugging
echo "DEBUG=socket,ssh,config" >> .env
docker-compose restart
```

### Custom Configuration

```bash
# Mount custom NGINX config
volumes:
  - ./custom-nginx.conf:/etc/nginx/conf.d/custom.conf:ro

# Override WebSSH2 config
volumes:
  - ./custom-webssh2-config.json:/usr/src/webssh2/config.json:ro
```

## 🤝 Contributing

### Development Workflow

1. Fork the repository
2. Create feature branch: `git checkout -b feature/new-feature`
3. Make changes and test thoroughly
4. Update documentation
5. Submit pull request

### Testing Requirements

- All tests must pass: `./tests/run-all-tests.sh`
- FIPS compliance verified
- Security scan clean: `docker scan nginx-webssh2:latest`
- Performance benchmarks maintained

## 🚢 Container Registry & CI/CD

> 📖 **Full workflow documentation**: See [GITHUB_WORKFLOW.md](GITHUB_WORKFLOW.md) for detailed CI/CD setup and usage

### GitHub Container Registry

Pre-built images are available at `ghcr.io/f5gov/nginx-webssh2` with the following tags:

- `latest` - Latest stable release from main branch
- `v1.0.0`, `v1.0`, `v1` - Semantic versioning tags
- `main-<sha>` - Commit-specific builds from main branch
- `pr-<number>` - Pull request preview builds

### Multi-Architecture Support

Images are built for multiple architectures:

- `linux/amd64` - Intel/AMD 64-bit
- `linux/arm64` - ARM 64-bit (Apple Silicon, AWS Graviton)

### Automated Build Pipeline

Every push to main branch and tagged release triggers:

1. Multi-architecture Docker build
2. Vulnerability scanning with Trivy
3. Container attestation generation
4. Automatic push to GitHub Container Registry

### Using with Docker Compose

```yaml
services:
  nginx-webssh2:
    image: ghcr.io/f5gov/nginx-webssh2:latest
    ports:
      - "443:443"
    environment:
      WEBSSH2_SESSION_SECRET: "your-secret-key"
      # Additional configuration...
```

## 📋 Changelog

### v1.0.0

- Initial release with UBI8 base
- FIPS 140-2 compliance
- mTLS support

### Roadmap

- [ ] Let's Encrypt integration
- [ ] OAuth2/OIDC authentication
- [ ] Prometheus metrics
- [x] ARM64 support (multi-arch builds)
- [x] GitHub Container Registry publishing

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
