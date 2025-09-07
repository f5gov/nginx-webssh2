#!/bin/bash

# FIPS Mode Verification Script
# Verifies that FIPS mode is properly enabled and configured

set -e

# Source environment variables
if [[ -f /etc/webssh2-env ]]; then
    source /etc/webssh2-env
fi

echo "[FIPS] Checking FIPS mode configuration..."

# Debug: Check environment variables availability
echo "[FIPS] Debug - checking environment variables..."
echo "[FIPS] FIPS_MODE from environment: '${FIPS_MODE:-UNSET}'"

# Check if FIPS mode should be enabled
if [[ "${FIPS_MODE}" == "enabled" ]]; then
    echo "[FIPS] FIPS mode is requested"
    
    # Check if FIPS mode is enabled in the kernel
    if [[ -f /proc/sys/crypto/fips_enabled ]]; then
        FIPS_KERNEL_STATUS=$(cat /proc/sys/crypto/fips_enabled)
        if [[ "${FIPS_KERNEL_STATUS}" == "1" ]]; then
            echo "[FIPS] ✓ FIPS mode is enabled in kernel"
        else
            echo "[FIPS] ⚠ FIPS mode is NOT enabled in kernel"
            if [[ "${FIPS_CHECK}" == "true" ]]; then
                echo "[FIPS] ERROR: FIPS mode required but not enabled in kernel"
                echo "[FIPS] This container must run on a FIPS-enabled host"
                exit 1
            else
                echo "[FIPS] WARNING: Continuing without kernel FIPS mode"
            fi
        fi
    else
        echo "[FIPS] ⚠ Cannot determine kernel FIPS status (/proc/sys/crypto/fips_enabled not found)"
        if [[ "${FIPS_CHECK}" == "true" ]]; then
            echo "[FIPS] ERROR: Cannot verify FIPS mode"
            exit 1
        fi
    fi
    
    # Check OpenSSL FIPS mode
    echo "[FIPS] Checking OpenSSL FIPS configuration..."
    
    # Test OpenSSL FIPS capability
    if openssl version -a | grep -q "OPENSSLDIR"; then
        echo "[FIPS] ✓ OpenSSL is available"
        
        # Check if OpenSSL was compiled with FIPS support
        if openssl list -providers 2>/dev/null | grep -q "fips" || \
           openssl version -a | grep -qi "fips"; then
            echo "[FIPS] ✓ OpenSSL has FIPS support"
        else
            echo "[FIPS] ⚠ OpenSSL FIPS support not detected"
            if [[ "${FIPS_CHECK}" == "true" ]]; then
                echo "[FIPS] ERROR: OpenSSL without FIPS support"
                exit 1
            fi
        fi
    else
        echo "[FIPS] ERROR: OpenSSL not found"
        exit 1
    fi
    
    # Check crypto policy
    if command -v update-crypto-policies >/dev/null 2>&1; then
        CRYPTO_POLICY=$(update-crypto-policies --show 2>/dev/null || echo "unknown")
        echo "[FIPS] Current crypto policy: ${CRYPTO_POLICY}"
        
        if [[ "${CRYPTO_POLICY}" == "FIPS" ]]; then
            echo "[FIPS] ✓ System crypto policy is set to FIPS"
        else
            echo "[FIPS] ⚠ System crypto policy is not FIPS (${CRYPTO_POLICY})"
            if [[ "${FIPS_CHECK}" == "true" ]]; then
                echo "[FIPS] ERROR: Non-FIPS crypto policy detected"
                exit 1
            fi
        fi
    else
        echo "[FIPS] ⚠ crypto-policies tool not available"
    fi
    
    echo "[FIPS] FIPS mode check completed"
    
elif [[ "${FIPS_MODE}" == "disabled" ]]; then
    echo "[FIPS] FIPS mode is disabled by configuration"
else
    echo "[FIPS] ERROR: Invalid FIPS_MODE value: ${FIPS_MODE}"
    echo "[FIPS] Must be 'enabled' or 'disabled'"
    exit 1
fi

echo "[FIPS] Configuration check complete"