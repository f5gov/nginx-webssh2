#!/bin/bash

# Installation and management script for NGINX + WebSSH2 on RHEL with Podman
# Equivalent to docker-compose deployment for standalone RHEL systems
#
# Usage:
#   ./install.sh [command] [options]
#
# Commands:
#   install     Install and configure the service
#   uninstall   Remove the service and cleanup
#   start       Start the service
#   stop        Stop the service
#   restart     Restart the service
#   status      Show service status
#   logs        Show service logs
#   update      Update container image and restart
#   health      Check service health
#   build       Build container image locally
#
# Options:
#   --system    Install as system service (default)
#   --user      Install as user service (rootless)
#   --force     Force operation without confirmation
#   --help      Show this help message

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SERVICE_NAME="nginx-webssh2"
CONTAINER_IMAGE="localhost/$SERVICE_NAME:latest"

# Installation paths
SYSTEM_INSTALL_DIR="/opt/$SERVICE_NAME"
SYSTEM_SERVICE_DIR="/etc/systemd/system"
USER_SERVICE_DIR="$HOME/.config/systemd/user"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default options
INSTALL_TYPE="system"
FORCE_MODE=false

# Parse command line arguments
parse_args() {
    COMMAND=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            install|uninstall|start|stop|restart|status|logs|update|health|build)
                COMMAND="$1"
                shift
                ;;
            --system)
                INSTALL_TYPE="system"
                shift
                ;;
            --user)
                INSTALL_TYPE="user"
                shift
                ;;
            --force)
                FORCE_MODE=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown argument: $1${NC}" >&2
                show_help >&2
                exit 1
                ;;
        esac
    done
    
    if [[ -z "$COMMAND" ]]; then
        echo -e "${RED}No command specified${NC}" >&2
        show_help >&2
        exit 1
    fi
}

# Show help message
show_help() {
    cat << EOF
NGINX + WebSSH2 Installation and Management Script for RHEL/Podman

Usage: $0 COMMAND [OPTIONS]

COMMANDS:
    install     Install and configure the service
    uninstall   Remove the service and cleanup
    start       Start the service
    stop        Stop the service  
    restart     Restart the service
    status      Show service status
    logs        Show service logs
    update      Update container image and restart
    health      Check service health
    build       Build container image locally

OPTIONS:
    --system    Install as system service (default)
    --user      Install as user service (rootless)
    --force     Force operation without confirmation
    --help      Show this help message

EXAMPLES:
    $0 install                    # Install as system service
    $0 install --user            # Install as user service
    $0 build                     # Build container image
    $0 start                     # Start the service
    $0 status                    # Check service status
    $0 logs                      # View service logs
    $0 health                    # Check service health
    $0 update                    # Update and restart

EOF
}

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Check if running as root (needed for system install)
check_root() {
    if [[ "$INSTALL_TYPE" == "system" ]] && [[ $EUID -ne 0 ]]; then
        log_error "System installation requires root privileges"
        log_info "Run with 'sudo $0 $COMMAND --system' or use '--user' for rootless installation"
        exit 1
    fi
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing_packages=()
    
    # Check for podman
    if ! command -v podman &> /dev/null; then
        missing_packages+=("podman")
    fi
    
    # Check for systemctl
    if ! command -v systemctl &> /dev/null; then
        missing_packages+=("systemd")
    fi
    
    # Check for buildah (needed for building)
    if [[ "$COMMAND" == "build" ]] && ! command -v buildah &> /dev/null; then
        missing_packages+=("buildah")
    fi
    
    # Check for useful tools
    if ! command -v curl &> /dev/null; then
        missing_packages+=("curl")
    fi
    
    if [[ ${#missing_packages[@]} -gt 0 ]]; then
        log_error "Missing required packages: ${missing_packages[*]}"
        log_info "Install with: sudo dnf install ${missing_packages[*]}"
        return 1
    fi
    
    # Check for WebSSH2 source code
    if [[ ! -d "$PROJECT_DIR/webssh2" ]]; then
        log_error "WebSSH2 source directory not found at: $PROJECT_DIR/webssh2"
        log_info "Make sure you have the WebSSH2 source code in the parent directory"
        return 1
    fi
    
    # Check for Dockerfile
    if [[ ! -f "$PROJECT_DIR/Dockerfile" ]]; then
        log_error "Dockerfile not found at: $PROJECT_DIR/Dockerfile"
        return 1
    fi
    
    log_success "Prerequisites check passed"
}

# Configure SELinux
configure_selinux() {
    if ! command -v getenforce &> /dev/null; then
        log_warn "SELinux tools not available, skipping SELinux configuration"
        return 0
    fi
    
    local selinux_status
    selinux_status=$(getenforce)
    
    if [[ "$selinux_status" == "Enforcing" ]] || [[ "$selinux_status" == "Permissive" ]]; then
        log_info "Configuring SELinux contexts..."
        
        # Set contexts for installation directory
        if [[ "$INSTALL_TYPE" == "system" ]]; then
            semanage fcontext -a -t container_file_t "$SYSTEM_INSTALL_DIR(/.*)?" 2>/dev/null || true
            restorecon -R "$SYSTEM_INSTALL_DIR" 2>/dev/null || true
        fi
        
        # Set contexts for service files
        if [[ "$INSTALL_TYPE" == "system" ]]; then
            restorecon "$SYSTEM_SERVICE_DIR/${SERVICE_NAME}*.service" 2>/dev/null || true
        fi
        
        log_success "SELinux contexts configured"
    else
        log_info "SELinux is disabled, skipping SELinux configuration"
    fi
}

# Configure firewall
configure_firewall() {
    if ! command -v firewall-cmd &> /dev/null; then
        log_warn "Firewall tools not available, skipping firewall configuration"
        return 0
    fi
    
    if ! systemctl is-active --quiet firewalld; then
        log_warn "Firewalld is not running, skipping firewall configuration"
        return 0
    fi
    
    log_info "Configuring firewall rules..."
    
    # Allow HTTPS traffic
    if ! firewall-cmd --list-services | grep -q https; then
        firewall-cmd --permanent --add-service=https
        firewall-cmd --reload
        log_success "HTTPS service added to firewall"
    else
        log_info "HTTPS service already configured in firewall"
    fi
}

# Build container image
build_image() {
    log_info "Building container image: $CONTAINER_IMAGE"
    
    cd "$PROJECT_DIR"
    
    # Build using podman
    podman build \
        -t "$CONTAINER_IMAGE" \
        -f Dockerfile \
        .
    
    log_success "Container image built successfully"
}

# Install service
install_service() {
    log_info "Installing $SERVICE_NAME service ($INSTALL_TYPE mode)..."
    
    check_prerequisites
    
    local install_dir
    local service_dir
    
    if [[ "$INSTALL_TYPE" == "system" ]]; then
        check_root
        install_dir="$SYSTEM_INSTALL_DIR"
        service_dir="$SYSTEM_SERVICE_DIR"
        
        # Create system user for nginx
        if ! id nginx &>/dev/null; then
            useradd --system --shell /sbin/nologin --home-dir /var/lib/nginx --create-home nginx
            log_success "Created nginx system user"
        fi
    else
        install_dir="$HOME/.local/share/$SERVICE_NAME"
        service_dir="$USER_SERVICE_DIR"
        mkdir -p "$service_dir"
    fi
    
    # Create installation directory
    mkdir -p "$install_dir"
    
    # Copy configuration files
    cp "$SCRIPT_DIR/nginx-webssh2-pod.yaml" "$install_dir/"
    cp "$SCRIPT_DIR/nginx-webssh2.env" "$install_dir/"
    cp "$SCRIPT_DIR/sync-docker-compose.sh" "$install_dir/"
    cp "$0" "$install_dir/manage.sh"
    chmod +x "$install_dir/manage.sh" "$install_dir/sync-docker-compose.sh"
    
    # Copy service files
    cp "$SCRIPT_DIR/${SERVICE_NAME}-pod.service" "$service_dir/"
    cp "$SCRIPT_DIR/${SERVICE_NAME}.service" "$service_dir/"
    
    # Update service file paths for installation directory
    sed -i "s|WorkingDirectory=.*|WorkingDirectory=$install_dir|" "$service_dir/${SERVICE_NAME}-pod.service"
    sed -i "s|EnvironmentFile=.*nginx-webssh2.env|EnvironmentFile=$install_dir/nginx-webssh2.env|" "$service_dir/${SERVICE_NAME}-pod.service"
    
    sed -i "s|WorkingDirectory=.*|WorkingDirectory=$install_dir|" "$service_dir/${SERVICE_NAME}.service"
    sed -i "s|EnvironmentFile=.*nginx-webssh2.env|EnvironmentFile=$install_dir/nginx-webssh2.env|" "$service_dir/${SERVICE_NAME}.service"
    
    # Set ownership
    if [[ "$INSTALL_TYPE" == "system" ]]; then
        chown -R nginx:nginx "$install_dir"
        chmod 755 "$install_dir"
        chmod 644 "$install_dir"/*.{yaml,env}
    fi
    
    # Configure SELinux and firewall
    configure_selinux
    configure_firewall
    
    # Reload systemd
    if [[ "$INSTALL_TYPE" == "system" ]]; then
        systemctl daemon-reload
    else
        systemctl --user daemon-reload
    fi
    
    # Enable service (using pod-based service by default)
    if [[ "$INSTALL_TYPE" == "system" ]]; then
        systemctl enable "${SERVICE_NAME}-pod"
    else
        systemctl --user enable "${SERVICE_NAME}-pod"
    fi
    
    log_success "Service installed successfully"
    log_info "Configuration directory: $install_dir"
    log_info "Service files: $service_dir"
    
    echo
    log_info "Next steps:"
    echo "1. Edit configuration: $install_dir/nginx-webssh2.env"
    echo "2. Build container image: $install_dir/manage.sh build"
    echo "3. Start service: $install_dir/manage.sh start"
    echo "4. Check status: $install_dir/manage.sh status"
}

# Uninstall service
uninstall_service() {
    log_warn "Uninstalling $SERVICE_NAME service ($INSTALL_TYPE mode)..."
    
    if [[ "$FORCE_MODE" != "true" ]]; then
        read -p "Are you sure you want to uninstall? This will remove all configurations. [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Uninstallation cancelled"
            return 0
        fi
    fi
    
    local install_dir
    local service_dir
    local systemctl_cmd="systemctl"
    
    if [[ "$INSTALL_TYPE" == "system" ]]; then
        check_root
        install_dir="$SYSTEM_INSTALL_DIR"
        service_dir="$SYSTEM_SERVICE_DIR"
    else
        install_dir="$HOME/.local/share/$SERVICE_NAME"
        service_dir="$USER_SERVICE_DIR"
        systemctl_cmd="systemctl --user"
    fi
    
    # Stop and disable services
    $systemctl_cmd stop "${SERVICE_NAME}-pod" 2>/dev/null || true
    $systemctl_cmd stop "$SERVICE_NAME" 2>/dev/null || true
    $systemctl_cmd disable "${SERVICE_NAME}-pod" 2>/dev/null || true
    $systemctl_cmd disable "$SERVICE_NAME" 2>/dev/null || true
    
    # Remove service files
    rm -f "$service_dir/${SERVICE_NAME}-pod.service"
    rm -f "$service_dir/${SERVICE_NAME}.service"
    
    # Remove installation directory
    rm -rf "$install_dir"
    
    # Reload systemd
    $systemctl_cmd daemon-reload
    
    # Remove container and images
    podman container rm -f "$SERVICE_NAME" 2>/dev/null || true
    podman pod rm -f "$SERVICE_NAME" 2>/dev/null || true
    podman image rm -f "$CONTAINER_IMAGE" 2>/dev/null || true
    
    log_success "Service uninstalled successfully"
}

# Service management functions
manage_service() {
    local action="$1"
    local systemctl_cmd="systemctl"
    local service_name="${SERVICE_NAME}-pod"  # Use pod-based service by default
    
    if [[ "$INSTALL_TYPE" == "user" ]]; then
        systemctl_cmd="systemctl --user"
    fi
    
    case "$action" in
        start)
            log_info "Starting $SERVICE_NAME service..."
            $systemctl_cmd start "$service_name"
            log_success "Service started"
            ;;
        stop)
            log_info "Stopping $SERVICE_NAME service..."
            $systemctl_cmd stop "$service_name"
            log_success "Service stopped"
            ;;
        restart)
            log_info "Restarting $SERVICE_NAME service..."
            $systemctl_cmd restart "$service_name"
            log_success "Service restarted"
            ;;
        status)
            $systemctl_cmd status "$service_name" --no-pager
            ;;
        logs)
            journalctl -u "$service_name" -f --no-pager
            ;;
    esac
}

# Health check
health_check() {
    log_info "Performing health check..."
    
    # Check if service is running
    local systemctl_cmd="systemctl"
    if [[ "$INSTALL_TYPE" == "user" ]]; then
        systemctl_cmd="systemctl --user"
    fi
    
    if $systemctl_cmd is-active --quiet "${SERVICE_NAME}-pod"; then
        log_success "Service is active"
    else
        log_error "Service is not active"
        return 1
    fi
    
    # Check if port is listening
    if ss -tlnp | grep -q :443; then
        log_success "HTTPS port (443) is listening"
    else
        log_error "HTTPS port (443) is not listening"
        return 1
    fi
    
    # Try to connect to the service
    if curl -k -s --connect-timeout 10 https://localhost/health >/dev/null; then
        log_success "Health check endpoint responded"
    else
        log_warn "Health check endpoint not responding (this might be expected for self-signed certificates)"
    fi
    
    # Check container health if available
    if podman container exists "$SERVICE_NAME"; then
        local health_status
        health_status=$(podman container inspect "$SERVICE_NAME" --format='{{.State.Health.Status}}' 2>/dev/null || echo "unknown")
        
        if [[ "$health_status" == "healthy" ]]; then
            log_success "Container health check: $health_status"
        else
            log_warn "Container health check: $health_status"
        fi
    fi
    
    log_success "Health check completed"
}

# Update service
update_service() {
    log_info "Updating $SERVICE_NAME service..."
    
    # Rebuild image
    build_image
    
    # Restart service
    manage_service restart
    
    log_success "Service updated successfully"
}

# Main execution
main() {
    parse_args "$@"
    
    echo "NGINX + WebSSH2 Management Script for RHEL/Podman"
    echo "================================================="
    echo
    
    case "$COMMAND" in
        install)
            install_service
            ;;
        uninstall)
            uninstall_service
            ;;
        start|stop|restart|status|logs)
            manage_service "$COMMAND"
            ;;
        build)
            check_prerequisites
            build_image
            ;;
        health)
            health_check
            ;;
        update)
            check_prerequisites
            update_service
            ;;
        *)
            log_error "Unknown command: $COMMAND"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"