# NGINX + WebSSH2 for RHEL/Podman

A production-ready deployment of NGINX + WebSSH2 with FIPS 140-2 compliance for standalone Red Hat Enterprise Linux systems using Podman.

This configuration provides equivalent functionality to the Docker Compose setup but optimized for RHEL environments with systemd integration, SELinux support, and Podman container management.

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────┐    ┌─────────────┐
│   Browser       │───▶│    NGINX     │───▶│  WebSSH2    │
│   (Client)      │    │ (Proxy+TLS)  │    │ (Node.js)   │
└─────────────────┘    └──────────────┘    └─────────────┘
                              │
                              ▼
                       ┌──────────────┐
                       │   SSH Host   │
                       │   (Target)   │
                       └──────────────┘
```

## ✨ Features

### 🔒 RHEL-Specific Security
- **FIPS 140-2 Compliance**: Built with Red Hat UBI8 and FIPS-certified OpenSSL
- **SELinux Integration**: Proper SELinux contexts and policies
- **Systemd Integration**: Native systemd service units with proper dependencies
- **Firewalld Support**: Automatic firewall configuration
- **Rootless Option**: Support for rootless Podman deployment

### 🌐 Podman Advantages
- **Docker-free**: No Docker daemon required
- **Kubernetes YAML**: Uses standard Kubernetes pod specifications
- **Systemd Native**: Tight integration with systemd for process management
- **Resource Limits**: CPU and memory limits enforced by systemd
- **Security**: Enhanced security with rootless containers and SELinux

## 📋 Prerequisites

### System Requirements
- Red Hat Enterprise Linux 8+ or compatible (CentOS Stream, Rocky Linux, AlmaLinux)
- Podman 3.4+ 
- Systemd 243+
- 2GB RAM minimum, 4GB recommended
- 10GB free disk space

### Required Packages
```bash
# Install required packages
sudo dnf install -y podman buildah systemd curl yq jq

# Optional: Install additional tools
sudo dnf install -y firewalld selinux-policy-targeted policycoreutils-python-utils
```

### WebSSH2 Source Code
This deployment requires the WebSSH2 source code in a sibling directory:
```
webssh/
├── webssh2/              # WebSSH2 source code
└── nginx-webssh2/        # This project
    └── podman/           # Podman configurations
```

## 🚀 Quick Start

### 1. Clone and Prepare
```bash
# Clone WebSSH2 (if not already done)
git clone https://github.com/billchurch/webssh2.git

# Navigate to the podman directory
cd webssh2/nginx-webssh2/podman
```

### 2. Install (System Service)
```bash
# Install as system service (requires root)
sudo ./install.sh install --system

# Or install as user service (rootless)
./install.sh install --user
```

### 3. Configure
```bash
# Edit configuration (system install)
sudo vi /opt/nginx-webssh2/nginx-webssh2.env

# Or for user install
vi ~/.local/share/nginx-webssh2/nginx-webssh2.env
```

### 4. Build and Start
```bash
# Build container image (system install)
sudo /opt/nginx-webssh2/manage.sh build

# Start service
sudo /opt/nginx-webssh2/manage.sh start

# Check status
sudo /opt/nginx-webssh2/manage.sh status
```

### 5. Access
- **HTTPS**: https://localhost (self-signed certificate by default)
- **Health Check**: https://localhost/health

## ⚙️ Configuration

### Environment Variables
The main configuration file is `nginx-webssh2.env`. Key sections include:

#### TLS Configuration
```bash
# Certificate mode
TLS_MODE=self-signed  # Options: self-signed, provided, letsencrypt

# Self-signed certificate parameters
TLS_CERT_CN=webssh2.localhost
TLS_CERT_SAN="webssh2.localhost,localhost,127.0.0.1"

# FIPS-compliant cipher suites
TLS_CIPHERS="ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-GCM-SHA256"
```

#### NGINX Configuration
```bash
# Server settings
NGINX_LISTEN_PORT=443
NGINX_SERVER_NAME=webssh2.localhost

# Performance settings
NGINX_WORKER_PROCESSES=1
NGINX_WORKER_CONNECTIONS=1024
NGINX_RATE_LIMIT=10r/s
```

#### WebSSH2 Configuration
```bash
# Core settings
WEBSSH2_LISTEN_IP=127.0.0.1
WEBSSH2_LISTEN_PORT=2222

# SSH settings
WEBSSH2_SSH_HOST=""  # Empty for dynamic selection
WEBSSH2_SSH_ALGORITHMS_PRESET=modern

# Session security
WEBSSH2_SESSION_SECRET="your-secret-key-change-in-production"
```

### Production Configuration
For production deployments, create a separate configuration:

```bash
# Copy environment file
sudo cp /opt/nginx-webssh2/nginx-webssh2.env /opt/nginx-webssh2/nginx-webssh2.env.production

# Edit for production
sudo vi /opt/nginx-webssh2/nginx-webssh2.env.production
```

Key production changes:
```bash
# Use provided certificates
TLS_MODE=provided
TLS_CERT_PATH=/etc/nginx/certs/cert.pem
TLS_KEY_PATH=/etc/nginx/certs/key.pem

# Enable strict FIPS checking
FIPS_CHECK=true

# Restrict CORS origins
WEBSSH2_HTTP_ORIGINS="https://webssh2.example.com:443"

# Generate secure session secret
WEBSSH2_SESSION_SECRET="$(openssl rand -base64 32)"

# Performance tuning
NGINX_WORKER_PROCESSES=auto
NGINX_RATE_LIMIT=50r/s
NGINX_CONN_LIMIT=500
```

## 🔧 Management

### Service Management
```bash
# Start service
sudo systemctl start nginx-webssh2-pod

# Stop service
sudo systemctl stop nginx-webssh2-pod

# Restart service
sudo systemctl restart nginx-webssh2-pod

# Check status
sudo systemctl status nginx-webssh2-pod

# Enable auto-start
sudo systemctl enable nginx-webssh2-pod

# View logs
sudo journalctl -u nginx-webssh2-pod -f
```

### Container Management
```bash
# List running pods
podman pod list

# Inspect pod
podman pod inspect nginx-webssh2

# Execute command in container
podman exec -it nginx-webssh2-nginx-webssh2 /bin/bash

# View container logs
podman logs nginx-webssh2-nginx-webssh2
```

### Using Management Script
```bash
# All operations through management script
cd /opt/nginx-webssh2

# Service operations
sudo ./manage.sh start
sudo ./manage.sh stop
sudo ./manage.sh restart
sudo ./manage.sh status
sudo ./manage.sh logs

# Maintenance operations
sudo ./manage.sh build     # Rebuild container image
sudo ./manage.sh update    # Update and restart
sudo ./manage.sh health    # Health check
```

## 🔄 Keeping in Sync with Docker Compose

This deployment includes a synchronization script to keep Podman configurations in sync with the Docker Compose setup.

### Manual Synchronization
```bash
# Navigate to podman directory
cd /opt/nginx-webssh2

# Preview changes
sudo ./sync-docker-compose.sh --dry-run

# Apply changes interactively
sudo ./sync-docker-compose.sh

# Apply changes automatically
sudo ./sync-docker-compose.sh --auto

# Force update even if versions match
sudo ./sync-docker-compose.sh --force --auto
```

### Automated Synchronization
Set up a cron job to automatically sync configurations:

```bash
# Add to root crontab for system service
sudo crontab -e

# Check for updates daily at 2 AM
0 2 * * * /opt/nginx-webssh2/sync-docker-compose.sh --auto >> /var/log/nginx-webssh2-sync.log 2>&1
```

## 📊 Monitoring and Troubleshooting

### Health Checks
```bash
# Built-in health check
sudo /opt/nginx-webssh2/manage.sh health

# Manual health check
curl -k https://localhost/health

# Check service status
sudo systemctl status nginx-webssh2-pod

# Check container health
podman container inspect nginx-webssh2-nginx-webssh2 --format='{{.State.Health.Status}}'
```

### Log Analysis
```bash
# View service logs
sudo journalctl -u nginx-webssh2-pod -f

# View container logs
sudo podman logs -f nginx-webssh2-nginx-webssh2

# View NGINX logs (if mounted)
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

### Common Issues

#### Service Won't Start
```bash
# Check service status
sudo systemctl status nginx-webssh2-pod

# Check for port conflicts
sudo ss -tlnp | grep :443

# Verify container image exists
podman image list | grep nginx-webssh2
```

#### Certificate Issues
```bash
# Regenerate self-signed certificate
sudo podman exec nginx-webssh2-nginx-webssh2 /usr/local/bin/generate-self-signed-cert.sh

# Check certificate validity
openssl s_client -connect localhost:443 -servername localhost
```

#### SELinux Issues
```bash
# Check SELinux denials
sudo ausearch -m avc -ts recent

# Allow container access (if needed)
sudo setsebool -P container_manage_cgroup on
```

#### Firewall Issues
```bash
# Check firewall status
sudo firewall-cmd --list-all

# Add HTTPS service
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

## 🔒 Security Considerations

### FIPS Compliance
- **Host Requirements**: RHEL host must be FIPS-enabled for full compliance
- **Kernel Support**: Requires FIPS-compatible kernel
- **Algorithm Restrictions**: Only FIPS-approved ciphers and protocols

Enable FIPS on RHEL host:
```bash
# Enable FIPS mode (requires reboot)
sudo fips-mode-setup --enable
sudo reboot

# Verify FIPS mode
cat /proc/sys/crypto/fips_enabled  # Should return 1
```

### Network Security
```bash
# Restrict SSH access
WEBSSH2_SSH_HOST=internal-ssh-gateway.example.com

# CORS restrictions
WEBSSH2_HTTP_ORIGINS=https://webssh2.example.com:443
```

### Certificate Management
```bash
# For production, use proper certificates
mkdir -p /opt/nginx-webssh2/certs
cp your-cert.pem /opt/nginx-webssh2/certs/cert.pem
cp your-key.pem /opt/nginx-webssh2/certs/key.pem
chown nginx:nginx /opt/nginx-webssh2/certs/*
chmod 644 /opt/nginx-webssh2/certs/cert.pem
chmod 600 /opt/nginx-webssh2/certs/key.pem

# Update configuration
TLS_MODE=provided
TLS_CERT_PATH=/opt/nginx-webssh2/certs/cert.pem
TLS_KEY_PATH=/opt/nginx-webssh2/certs/key.pem
```

## 🚀 Production Deployment

### System Hardening
```bash
# Create dedicated user (if not using system install)
sudo useradd --system --shell /sbin/nologin nginx-webssh2

# Set proper file permissions
sudo chown -R nginx:nginx /opt/nginx-webssh2
sudo chmod 750 /opt/nginx-webssh2
sudo chmod 640 /opt/nginx-webssh2/*.env

# Configure log rotation
sudo cat > /etc/logrotate.d/nginx-webssh2 << EOF
/var/log/nginx-webssh2/*.log {
    weekly
    rotate 12
    compress
    delaycompress
    missingok
    notifempty
    create 644 nginx nginx
    postrotate
        systemctl reload nginx-webssh2-pod
    endscript
}
EOF
```

### Performance Tuning
```bash
# Update environment for production
NGINX_WORKER_PROCESSES=auto
NGINX_WORKER_CONNECTIONS=4096
NGINX_RATE_LIMIT=100r/s
NGINX_CONN_LIMIT=1000

# Increase system limits
echo "nginx soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "nginx hard nofile 65536" | sudo tee -a /etc/security/limits.conf
```

### Backup and Recovery
```bash
# Backup configuration
sudo tar -czf nginx-webssh2-backup-$(date +%Y%m%d).tar.gz /opt/nginx-webssh2

# Backup container image
podman save localhost/nginx-webssh2:latest | gzip > nginx-webssh2-image-backup-$(date +%Y%m%d).tar.gz

# Restore from backup
sudo tar -xzf nginx-webssh2-backup-*.tar.gz -C /
podman load < nginx-webssh2-image-backup-*.tar.gz
```

## 🔄 Migration from Docker Compose

### Migration Steps
1. **Stop Docker Compose services**:
   ```bash
   docker-compose -f docker-compose.yml down
   ```

2. **Export Docker configuration**:
   ```bash
   # Export environment variables
   docker-compose config | yq eval '.services.nginx-webssh2.environment' -
   ```

3. **Install Podman deployment**:
   ```bash
   sudo ./install.sh install --system
   ```

4. **Sync configurations**:
   ```bash
   sudo ./sync-docker-compose.sh --auto
   ```

5. **Build and start**:
   ```bash
   sudo /opt/nginx-webssh2/manage.sh build
   sudo /opt/nginx-webssh2/manage.sh start
   ```

### Configuration Differences
- **Networking**: Podman uses pod-based networking instead of Docker networks
- **Volumes**: Different volume syntax and SELinux contexts
- **Services**: Systemd services instead of Docker Compose
- **User Management**: Proper system user integration

## 📚 File Reference

### Core Files
- `nginx-webssh2-pod.yaml` - Kubernetes Pod specification for Podman
- `nginx-webssh2.env` - Environment configuration file
- `nginx-webssh2-pod.service` - Systemd service unit (pod-based)
- `nginx-webssh2.service` - Systemd service unit (container-based)
- `install.sh` - Installation and management script
- `sync-docker-compose.sh` - Docker Compose synchronization script

### Installation Locations
- **System install**: `/opt/nginx-webssh2/`
- **User install**: `~/.local/share/nginx-webssh2/`
- **Service files**: `/etc/systemd/system/` or `~/.config/systemd/user/`
- **Logs**: `journalctl -u nginx-webssh2-pod`

## ❓ FAQ

### Q: Can I run this alongside Docker?
A: Yes, Podman and Docker can coexist. They use different runtimes and don't conflict.

### Q: How do I enable rootless mode?
A: Use `./install.sh install --user` instead of the system install.

### Q: What about Let's Encrypt certificates?
A: Currently supported through manual certificate management. Automatic Let's Encrypt integration is planned for a future release.

### Q: How do I update the container?
A: Run `sudo /opt/nginx-webssh2/manage.sh update` to rebuild and restart.

### Q: Can I use custom NGINX configurations?
A: Yes, mount custom configurations as volumes in the Pod YAML file.

## 🤝 Contributing

### Development Workflow
1. Make changes to docker-compose.yml (if applicable)
2. Run synchronization: `./sync-docker-compose.sh --dry-run`
3. Test Podman deployment
4. Submit pull request

### Testing
```bash
# Test installation
sudo ./install.sh install --system --force
sudo /opt/nginx-webssh2/manage.sh build
sudo /opt/nginx-webssh2/manage.sh start
sudo /opt/nginx-webssh2/manage.sh health

# Test uninstallation
sudo ./install.sh uninstall --force
```

## 📄 License

MIT License - see [LICENSE](../LICENSE) file for details.

## 🆘 Support

- **Issues**: GitHub Issues
- **Documentation**: This README and inline comments
- **RHEL Support**: Red Hat Customer Portal for RHEL-specific issues

---

**⚠️ Security Notice**: This deployment includes FIPS 140-2 compliance features but requires a FIPS-enabled RHEL host system for full compliance. Always validate your specific compliance requirements and test thoroughly in your environment.