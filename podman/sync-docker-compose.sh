#!/bin/bash

# Synchronization script to keep Podman configurations in sync with docker-compose.yml
# This script parses docker-compose.yml and updates corresponding Podman files
#
# Usage:
#   ./sync-docker-compose.sh [--auto] [--dry-run] [--force]
#
# Options:
#   --auto     Automatically apply changes without confirmation
#   --dry-run  Show what would be changed without applying
#   --force    Force update even if versions match
#   --help     Show this help message

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$PROJECT_DIR/docker-compose.yml"
PODMAN_DIR="$SCRIPT_DIR"

# Files to sync
POD_YAML="$PODMAN_DIR/nginx-webssh2-pod.yaml"
ENV_FILE="$PODMAN_DIR/nginx-webssh2.env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Options
AUTO_MODE=false
DRY_RUN=false
FORCE_UPDATE=false

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --auto)
                AUTO_MODE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --force)
                FORCE_UPDATE=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}" >&2
                show_help >&2
                exit 1
                ;;
        esac
    done
}

# Show help message
show_help() {
    cat << EOF
Synchronization script for docker-compose.yml to Podman configurations

Usage: $0 [OPTIONS]

OPTIONS:
    --auto     Automatically apply changes without confirmation
    --dry-run  Show what would be changed without applying
    --force    Force update even if versions match
    --help     Show this help message

EXAMPLES:
    $0                    # Interactive sync
    $0 --dry-run         # Preview changes
    $0 --auto            # Auto-apply changes
    $0 --force --auto    # Force update everything

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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing_tools=()
    
    # Check for required tools
    if ! command -v yq &> /dev/null; then
        missing_tools+=("yq")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing_tools+=("jq")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Install with: sudo dnf install yq jq"
        return 1
    fi
    
    # Check if docker-compose.yml exists
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        log_error "docker-compose.yml not found at: $COMPOSE_FILE"
        return 1
    fi
    
    # Validate docker-compose.yml
    if ! yq eval '.' "$COMPOSE_FILE" > /dev/null 2>&1; then
        log_error "Invalid docker-compose.yml syntax"
        return 1
    fi
    
    log_success "Prerequisites check passed"
}

# Extract environment variables from docker-compose.yml
extract_environment_vars() {
    log_info "Extracting environment variables from docker-compose.yml..."
    
    yq eval '.services.nginx-webssh2.environment | to_entries | .[] | .key + "=" + .value' "$COMPOSE_FILE" 2>/dev/null || true
}

# Extract ports from docker-compose.yml
extract_ports() {
    log_info "Extracting port mappings from docker-compose.yml..."
    
    yq eval '.services.nginx-webssh2.ports[]' "$COMPOSE_FILE" 2>/dev/null || true
}

# Extract volumes from docker-compose.yml
extract_volumes() {
    log_info "Extracting volume mappings from docker-compose.yml..."
    
    yq eval '.services.nginx-webssh2.volumes[]?' "$COMPOSE_FILE" 2>/dev/null || true
}

# Extract resource limits from docker-compose.yml
extract_resources() {
    log_info "Extracting resource limits from docker-compose.yml..."
    
    local memory_limit
    local cpu_limit
    local memory_reservation
    local cpu_reservation
    
    memory_limit=$(yq eval '.services.nginx-webssh2.deploy.resources.limits.memory // ""' "$COMPOSE_FILE" 2>/dev/null)
    cpu_limit=$(yq eval '.services.nginx-webssh2.deploy.resources.limits.cpus // ""' "$COMPOSE_FILE" 2>/dev/null)
    memory_reservation=$(yq eval '.services.nginx-webssh2.deploy.resources.reservations.memory // ""' "$COMPOSE_FILE" 2>/dev/null)
    cpu_reservation=$(yq eval '.services.nginx-webssh2.deploy.resources.reservations.cpus // ""' "$COMPOSE_FILE" 2>/dev/null)
    
    echo "memory_limit=$memory_limit"
    echo "cpu_limit=$cpu_limit"
    echo "memory_reservation=$memory_reservation"
    echo "cpu_reservation=$cpu_reservation"
}

# Get docker-compose version/hash for tracking changes
get_compose_version() {
    # Create a hash of relevant sections to detect changes
    yq eval '.services.nginx-webssh2 | del(.image) | del(.build)' "$COMPOSE_FILE" | sha256sum | cut -d' ' -f1
}

# Get current Podman configuration version
get_podman_version() {
    if [[ -f "$POD_YAML" ]]; then
        # Extract version from comment or annotation
        grep -E "^# Version:" "$POD_YAML" | cut -d' ' -f3 || echo "unknown"
    else
        echo "not-found"
    fi
}

# Update environment file
update_env_file() {
    log_info "Updating environment file: $ENV_FILE"
    
    # Create backup
    if [[ -f "$ENV_FILE" ]]; then
        cp "$ENV_FILE" "${ENV_FILE}.backup.$(date +%Y%m%d-%H%M%S)"
    fi
    
    # Get environment variables from compose file
    local env_vars
    env_vars=$(extract_environment_vars)
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would update environment variables:"
        echo "$env_vars" | head -10
        [[ $(echo "$env_vars" | wc -l) -gt 10 ]] && echo "... and $(( $(echo "$env_vars" | wc -l) - 10 )) more"
        return 0
    fi
    
    # Update the environment file
    local temp_file
    temp_file=$(mktemp)
    
    # Keep the header and comments, replace the values
    awk '
        /^#/ || /^$/ { print; next }
        /^[A-Z_]+=/ {
            var = $0
            gsub(/=.*/, "", var)
            if (var in new_values) {
                print var "=" new_values[var]
                delete new_values[var]
            } else {
                print
            }
            next
        }
        { print }
        END {
            # Add any new variables not found in the original file
            for (var in new_values) {
                print var "=" new_values[var]
            }
        }
    ' new_values=<(echo "$env_vars" | awk -F= '{print $1, $2}' OFS='\034') "$ENV_FILE" > "$temp_file"
    
    mv "$temp_file" "$ENV_FILE"
    log_success "Environment file updated"
}

# Update Pod YAML file
update_pod_yaml() {
    log_info "Updating Pod YAML file: $POD_YAML"
    
    # Create backup
    if [[ -f "$POD_YAML" ]]; then
        cp "$POD_YAML" "${POD_YAML}.backup.$(date +%Y%m%d-%H%M%S)"
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would update Pod YAML with current docker-compose configuration"
        return 0
    fi
    
    local compose_version
    compose_version=$(get_compose_version)
    
    # Update version comment in YAML
    sed -i "1i# Version: $compose_version" "$POD_YAML"
    
    # Extract and update resource limits
    local resources
    resources=$(extract_resources)
    
    eval "$resources"  # Set variables: memory_limit, cpu_limit, etc.
    
    # Update resource limits in YAML (if they exist)
    if [[ -n "$memory_limit" ]]; then
        yq eval -i ".spec.containers[0].resources.limits.memory = \"$memory_limit\"" "$POD_YAML"
        # Also update annotation
        yq eval -i ".metadata.annotations.\"io.podman.memory-limit\" = \"$memory_limit\"" "$POD_YAML"
    fi
    
    if [[ -n "$cpu_limit" ]]; then
        # Convert decimal to millicores (e.g., 1.0 -> 1000m)
        local cpu_millicores
        cpu_millicores=$(echo "$cpu_limit * 1000" | bc | cut -d. -f1)
        yq eval -i ".spec.containers[0].resources.limits.cpu = \"${cpu_millicores}m\"" "$POD_YAML"
        yq eval -i ".metadata.annotations.\"io.podman.cpu-limit\" = \"$cpu_limit\"" "$POD_YAML"
    fi
    
    if [[ -n "$memory_reservation" ]]; then
        yq eval -i ".spec.containers[0].resources.requests.memory = \"$memory_reservation\"" "$POD_YAML"
        yq eval -i ".metadata.annotations.\"io.podman.memory-reservation\" = \"$memory_reservation\"" "$POD_YAML"
    fi
    
    if [[ -n "$cpu_reservation" ]]; then
        local cpu_reservation_millicores
        cpu_reservation_millicores=$(echo "$cpu_reservation * 1000" | bc | cut -d. -f1)
        yq eval -i ".spec.containers[0].resources.requests.cpu = \"${cpu_reservation_millicores}m\"" "$POD_YAML"
        yq eval -i ".metadata.annotations.\"io.podman.cpu-reservation\" = \"$cpu_reservation\"" "$POD_YAML"
    fi
    
    log_success "Pod YAML updated"
}

# Show differences
show_diff() {
    local compose_version
    local podman_version
    
    compose_version=$(get_compose_version)
    podman_version=$(get_podman_version)
    
    log_info "Configuration versions:"
    echo "  docker-compose.yml: $compose_version"
    echo "  Podman config:      $podman_version"
    
    if [[ "$compose_version" != "$podman_version" ]] || [[ "$FORCE_UPDATE" == "true" ]]; then
        log_warn "Configurations are out of sync"
        return 0
    else
        log_success "Configurations are in sync"
        return 1
    fi
}

# Main synchronization function
sync_configs() {
    log_info "Starting synchronization..."
    
    if ! check_prerequisites; then
        exit 1
    fi
    
    # Check if update is needed
    if ! show_diff && [[ "$FORCE_UPDATE" != "true" ]]; then
        log_success "No updates needed"
        return 0
    fi
    
    # Confirm changes unless in auto mode
    if [[ "$AUTO_MODE" != "true" ]] && [[ "$DRY_RUN" != "true" ]]; then
        echo
        read -p "Do you want to proceed with the synchronization? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Synchronization cancelled"
            return 0
        fi
    fi
    
    # Perform updates
    update_env_file
    update_pod_yaml
    
    if [[ "$DRY_RUN" != "true" ]]; then
        log_success "Synchronization completed successfully!"
        log_info "Backup files created with timestamp suffix"
        
        echo
        log_info "To apply changes:"
        echo "  sudo systemctl restart nginx-webssh2-pod"
        echo "  # or"
        echo "  podman play kube --replace --env-file nginx-webssh2.env nginx-webssh2-pod.yaml"
    fi
}

# Validate configuration after sync
validate_config() {
    log_info "Validating Podman configuration..."
    
    # Validate YAML syntax
    if ! yq eval '.' "$POD_YAML" > /dev/null 2>&1; then
        log_error "Invalid YAML syntax in $POD_YAML"
        return 1
    fi
    
    # Check environment file syntax
    if ! bash -n "$ENV_FILE" 2>/dev/null; then
        log_error "Invalid environment file syntax in $ENV_FILE"
        return 1
    fi
    
    log_success "Configuration validation passed"
}

# Cleanup function
cleanup() {
    # Clean up temporary files if any
    :
}

# Signal handlers
trap cleanup EXIT
trap 'log_error "Interrupted"; exit 130' INT TERM

# Main execution
main() {
    parse_args "$@"
    
    echo "Docker Compose to Podman Synchronization Tool"
    echo "============================================="
    echo
    
    sync_configs
    
    if [[ "$DRY_RUN" != "true" ]]; then
        validate_config
    fi
}

# Run main function with all arguments
main "$@"