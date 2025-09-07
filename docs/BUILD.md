# Building NGINX + WebSSH2

This document contains detailed build instructions for the nginx-webssh2 container.

## Prerequisites

- Docker and Docker Compose
- Access to Red Hat container registry (registry.access.redhat.com)
- Git with submodule support

## Clone Repository with Submodules

```bash
git clone --recursive https://github.com/f5gov/nginx-webssh2.git
cd nginx-webssh2

# If you already cloned without submodules
git submodule update --init --recursive
```

## Build and Run

### Using Docker Compose

```bash
# Configure environment
cp .env.example .env
# Edit .env with your settings

# Build using docker-compose
docker-compose up --build

# Access WebSSH2
# HTTPS: https://localhost (self-signed certificate)
# Health: https://localhost/health
```

### Manual Docker Build

```bash
# Build the image
docker build -t nginx-webssh2:latest .

# Run the container
docker run -d -p 443:443 --name nginx-webssh2 nginx-webssh2:latest
```

## Development Build

### Local Development Setup

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

## Testing Your Build

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

## Multi-Architecture Builds

The container supports multiple architectures:
- `linux/amd64` - Intel/AMD 64-bit
- `linux/arm64` - ARM 64-bit (Apple Silicon, AWS Graviton)

Build for specific architecture:

```bash
# Build for ARM64
docker buildx build --platform linux/arm64 -t nginx-webssh2:arm64 .

# Build for multiple platforms
docker buildx build --platform linux/amd64,linux/arm64 -t nginx-webssh2:multi .
```

## Repository Structure

```ascii
nginx-webssh2/
├── .github/
│   └── workflows/
│       └── publish.yml                    # GitHub Actions CI/CD workflow
├── GITHUB_WORKFLOW.md                     # Detailed workflow documentation
├── Dockerfile                              # Multi-stage container build
├── docker-compose.yml                      # Development/testing compose
├── .env.example                            # Environment configuration template
├── README.md                              # Main documentation
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

## Contributing

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

## CI/CD Pipeline

See [GITHUB_WORKFLOW.md](../GITHUB_WORKFLOW.md) for detailed CI/CD documentation.

### Automated Build Process

Every push triggers:
1. Multi-architecture Docker build
2. Vulnerability scanning with Trivy
3. Container attestation generation
4. Automatic push to GitHub Container Registry

## Troubleshooting

### Common Build Issues

1. **Submodule not initialized**: Run `git submodule update --init --recursive`
2. **Docker build fails**: Ensure Docker daemon is running and has sufficient resources
3. **FIPS validation fails**: Check host kernel FIPS support
4. **Certificate generation fails**: Verify OpenSSL installation and permissions
5. **Tests fail**: Check Docker network configuration and port availability