#!/bin/bash

# Health Check Script for NGINX + WebSSH2 Container
# Performs comprehensive health checks on both services

set -e

NGINX_PORT=${NGINX_LISTEN_PORT:-443}
WEBSSH2_PORT=${WEBSSH2_LISTEN_PORT:-2222}
WEBSSH2_IP=${WEBSSH2_LISTEN_IP:-127.0.0.1}

# Exit codes
EXIT_OK=0
EXIT_WARNING=1
EXIT_CRITICAL=2

# Health check result
HEALTH_STATUS=$EXIT_OK
HEALTH_MESSAGES=()

# Function to add health message
add_message() {
    local level=$1
    local message=$2
    HEALTH_MESSAGES+=("[$level] $message")
    
    case $level in
        "CRITICAL")
            HEALTH_STATUS=$EXIT_CRITICAL
            ;;
        "WARNING")
            if [[ $HEALTH_STATUS -eq $EXIT_OK ]]; then
                HEALTH_STATUS=$EXIT_WARNING
            fi
            ;;
    esac
}

# Check if NGINX is running
check_nginx_process() {
    if pgrep nginx > /dev/null 2>&1; then
        add_message "OK" "NGINX process is running"
        return 0
    else
        add_message "CRITICAL" "NGINX process is not running"
        return 1
    fi
}

# Check if WebSSH2 is running
check_webssh2_process() {
    if pgrep -f "node.*dist/index.js" > /dev/null 2>&1; then
        add_message "OK" "WebSSH2 process is running"
        return 0
    else
        add_message "CRITICAL" "WebSSH2 process is not running"
        return 1
    fi
}

# NGINX HTTP check removed - HTTPS only configuration

# Check NGINX HTTPS response
check_nginx_https() {
    local timeout=5
    
    # Check HTTPS health endpoint
    if curl -f -s -k -m $timeout "https://localhost:${NGINX_PORT}/health" > /dev/null 2>&1; then
        add_message "OK" "NGINX HTTPS endpoint responding"
    else
        add_message "CRITICAL" "NGINX HTTPS endpoint not responding"
        return 1
    fi
    
    # Check main application endpoint
    if curl -f -s -k -m $timeout "https://localhost:${NGINX_PORT}/ssh/" > /dev/null 2>&1; then
        add_message "OK" "WebSSH2 application accessible via NGINX"
    else
        add_message "WARNING" "WebSSH2 application not accessible via NGINX"
    fi
}

# Check WebSSH2 direct connection
check_webssh2_direct() {
    local timeout=3
    
    # Check if WebSSH2 is listening on its port
    if timeout $timeout bash -c "echo > /dev/tcp/${WEBSSH2_IP}/${WEBSSH2_PORT}" 2>/dev/null; then
        add_message "OK" "WebSSH2 listening on ${WEBSSH2_IP}:${WEBSSH2_PORT}"
    else
        add_message "CRITICAL" "WebSSH2 not listening on ${WEBSSH2_IP}:${WEBSSH2_PORT}"
        return 1
    fi
}

# Check certificate validity
check_certificate() {
    local cert_path="${TLS_CERT_PATH:-/etc/nginx/certs/cert.pem}"
    
    if [[ -f "$cert_path" ]]; then
        # Check if certificate is valid (not expired)
        if openssl x509 -checkend 86400 -noout -in "$cert_path" > /dev/null 2>&1; then
            add_message "OK" "TLS certificate is valid"
        else
            add_message "WARNING" "TLS certificate expires within 24 hours"
        fi
        
        # Check certificate format
        if openssl x509 -in "$cert_path" -noout > /dev/null 2>&1; then
            add_message "OK" "TLS certificate format is valid"
        else
            add_message "CRITICAL" "TLS certificate format is invalid"
        fi
    else
        add_message "CRITICAL" "TLS certificate file not found: $cert_path"
    fi
}

# Check disk space
check_disk_space() {
    local usage
    usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [[ $usage -lt 90 ]]; then
        add_message "OK" "Disk usage: ${usage}%"
    elif [[ $usage -lt 95 ]]; then
        add_message "WARNING" "Disk usage high: ${usage}%"
    else
        add_message "CRITICAL" "Disk usage critical: ${usage}%"
    fi
}

# Check memory usage
check_memory() {
    local mem_usage
    mem_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    
    if [[ $mem_usage -lt 90 ]]; then
        add_message "OK" "Memory usage: ${mem_usage}%"
    elif [[ $mem_usage -lt 95 ]]; then
        add_message "WARNING" "Memory usage high: ${mem_usage}%"
    else
        add_message "CRITICAL" "Memory usage critical: ${mem_usage}%"
    fi
}

# Check FIPS mode if enabled
check_fips() {
    if [[ "${FIPS_MODE}" == "enabled" ]]; then
        if [[ -f /proc/sys/crypto/fips_enabled ]] && [[ "$(cat /proc/sys/crypto/fips_enabled)" == "1" ]]; then
            add_message "OK" "FIPS mode is enabled"
        else
            add_message "WARNING" "FIPS mode requested but not enabled in kernel"
        fi
    else
        add_message "OK" "FIPS mode is disabled"
    fi
}

# Main health check execution
main() {
    echo "=== Health Check Started at $(date) ==="
    
    # Core service checks
    check_nginx_process
    check_webssh2_process
    
    # Network connectivity checks
    check_nginx_https
    check_webssh2_direct
    
    # Certificate check
    check_certificate
    
    # System resource checks
    check_disk_space
    check_memory
    
    # Security checks
    check_fips
    
    # Output results
    echo
    echo "=== Health Check Results ==="
    for message in "${HEALTH_MESSAGES[@]}"; do
        echo "$message"
    done
    
    echo
    case $HEALTH_STATUS in
        $EXIT_OK)
            echo "Overall Status: HEALTHY"
            ;;
        $EXIT_WARNING)
            echo "Overall Status: WARNING"
            ;;
        $EXIT_CRITICAL)
            echo "Overall Status: CRITICAL"
            ;;
    esac
    
    echo "=== Health Check Completed ==="
    
    exit $HEALTH_STATUS
}

# Run health check
main "$@"