#!/usr/bin/env bats
# Test suite for validating README.md deployment examples
# Tests container deployment scenarios documented in README.md

load test_helper

# Setup: Generate test session secret
setup() {
  export TEST_SESSION_SECRET="$(openssl rand -base64 32)"
  export TEST_CONTAINER_PREFIX="nginx-webssh2-test"
  export TEST_PORT=8443
}

# Teardown: Clean up test containers
teardown() {
  docker rm -f "${TEST_CONTAINER_PREFIX}-${BATS_TEST_NUMBER}" 2>/dev/null || true
}

# ==============================================================================
# Basic Deployment Tests
# ==============================================================================

@test "README Example: Basic deployment with session secret" {
  # Test: Basic deployment from README
  docker run -d \
    -p ${TEST_PORT}:443 \
    --name "${TEST_CONTAINER_PREFIX}-${BATS_TEST_NUMBER}" \
    -e WEBSSH2_SESSION_SECRET="${TEST_SESSION_SECRET}" \
    ghcr.io/F5GovSolutions/nginx-webssh2:latest

  # Wait for container to start
  sleep 10

  # Verify container is running
  run docker ps --filter "name=${TEST_CONTAINER_PREFIX}-${BATS_TEST_NUMBER}" --format "{{.Status}}"
  assert_output --partial "Up"
}

@test "README Example: Health check endpoint responds" {
  # Test: Health check endpoint from README
  docker run -d \
    -p ${TEST_PORT}:443 \
    --name "${TEST_CONTAINER_PREFIX}-${BATS_TEST_NUMBER}" \
    -e WEBSSH2_SESSION_SECRET="${TEST_SESSION_SECRET}" \
    ghcr.io/F5GovSolutions/nginx-webssh2:latest

  # Wait for services to be ready
  sleep 15

  # Test health endpoint
  run curl -k -f https://localhost:${TEST_PORT}/health
  assert_success
}

@test "README Example: Container healthcheck script works" {
  docker run -d \
    -p ${TEST_PORT}:443 \
    --name "${TEST_CONTAINER_PREFIX}-${BATS_TEST_NUMBER}" \
    -e WEBSSH2_SESSION_SECRET="${TEST_SESSION_SECRET}" \
    -e FIPS_MODE=disabled \
    -e FIPS_CHECK=false \
    ghcr.io/F5GovSolutions/nginx-webssh2:latest

  sleep 10

  # Test internal healthcheck script
  run docker exec "${TEST_CONTAINER_PREFIX}-${BATS_TEST_NUMBER}" /usr/local/bin/healthcheck.sh
  assert_success
}

# ==============================================================================
# TLS/SSL Configuration Tests
# ==============================================================================

@test "README Example: Self-signed TLS mode (default)" {
  docker run -d \
    -p ${TEST_PORT}:443 \
    --name "${TEST_CONTAINER_PREFIX}-${BATS_TEST_NUMBER}" \
    -e WEBSSH2_SESSION_SECRET="${TEST_SESSION_SECRET}" \
    -e TLS_MODE=self-signed \
    ghcr.io/F5GovSolutions/nginx-webssh2:latest

  sleep 10

  # Verify container is running
  run docker ps --filter "name=${TEST_CONTAINER_PREFIX}-${BATS_TEST_NUMBER}" --format "{{.Status}}"
  assert_output --partial "Up"

  # Test TLS connection
  run openssl s_client -connect localhost:${TEST_PORT} -showcerts </dev/null
  assert_success
}

@test "README Example: Custom self-signed certificate with SAN" {
  docker run -d \
    -p ${TEST_PORT}:443 \
    --name "${TEST_CONTAINER_PREFIX}-${BATS_TEST_NUMBER}" \
    -e WEBSSH2_SESSION_SECRET="${TEST_SESSION_SECRET}" \
    -e TLS_MODE=self-signed \
    -e TLS_CERT_CN=test.localhost \
    -e TLS_CERT_SAN="test.localhost,localhost,127.0.0.1" \
    ghcr.io/F5GovSolutions/nginx-webssh2:latest

  sleep 10

  # Verify certificate contains correct CN
  run docker exec "${TEST_CONTAINER_PREFIX}-${BATS_TEST_NUMBER}" \
    openssl x509 -in /etc/nginx/certs/cert.pem -noout -subject
  assert_output --partial "test.localhost"
}

# ==============================================================================
# Environment Variable Tests
# ==============================================================================

@test "README Example: SSH target configuration" {
  docker run -d \
    -p ${TEST_PORT}:443 \
    --name "${TEST_CONTAINER_PREFIX}-${BATS_TEST_NUMBER}" \
    -e WEBSSH2_SESSION_SECRET="${TEST_SESSION_SECRET}" \
    -e WEBSSH2_SSH_HOST=ssh.example.com \
    -e WEBSSH2_SSH_PORT=22 \
    ghcr.io/F5GovSolutions/nginx-webssh2:latest

  sleep 10

  # Verify environment variables are set
  run docker exec "${TEST_CONTAINER_PREFIX}-${BATS_TEST_NUMBER}" env
  assert_output --partial "WEBSSH2_SSH_HOST=ssh.example.com"
  assert_output --partial "WEBSSH2_SSH_PORT=22"
}

@test "README Example: FIPS mode enabled" {
  docker run -d \
    -p ${TEST_PORT}:443 \
    --name "${TEST_CONTAINER_PREFIX}-${BATS_TEST_NUMBER}" \
    -e WEBSSH2_SESSION_SECRET="${TEST_SESSION_SECRET}" \
    -e FIPS_MODE=enabled \
    -e FIPS_CHECK=false \
    ghcr.io/F5GovSolutions/nginx-webssh2:latest

  sleep 10

  # Verify container started with FIPS mode
  run docker logs "${TEST_CONTAINER_PREFIX}-${BATS_TEST_NUMBER}"
  assert_output --partial "FIPS"
}

@test "README Example: Rate limiting configuration" {
  docker run -d \
    -p ${TEST_PORT}:443 \
    --name "${TEST_CONTAINER_PREFIX}-${BATS_TEST_NUMBER}" \
    -e WEBSSH2_SESSION_SECRET="${TEST_SESSION_SECRET}" \
    -e NGINX_RATE_LIMIT=10r/s \
    -e NGINX_RATE_LIMIT_BURST=20 \
    -e NGINX_CONN_LIMIT=100 \
    ghcr.io/F5GovSolutions/nginx-webssh2:latest

  sleep 10

  # Verify NGINX is running
  run docker exec "${TEST_CONTAINER_PREFIX}-${BATS_TEST_NUMBER}" pgrep nginx
  assert_success
}

# ==============================================================================
# Logging Configuration Tests
# ==============================================================================

@test "README Example: NGINX access logging emits entries by default" {
  docker run -d \
    -p ${TEST_PORT}:443 \
    --name "${TEST_CONTAINER_PREFIX}-${BATS_TEST_NUMBER}" \
    -e WEBSSH2_SESSION_SECRET="${TEST_SESSION_SECRET}" \
    ghcr.io/F5GovSolutions/nginx-webssh2:latest

  sleep 10

  # Make requests that generate access log entries
  curl -k https://localhost:${TEST_PORT}/health || true
  curl -k https://localhost:${TEST_PORT}/ssh/ || true
  sleep 2

  # Access log should contain recent entries
  run docker exec "${TEST_CONTAINER_PREFIX}-${BATS_TEST_NUMBER}" \
    sh -c 'tail -1 /var/log/nginx/access.log'
  assert_success
  assert_output --partial "/ssh/"
}

@test "README Example: NGINX access logging enabled" {
  docker run -d \
    -p ${TEST_PORT}:443 \
    --name "${TEST_CONTAINER_PREFIX}-${BATS_TEST_NUMBER}" \
    -e WEBSSH2_SESSION_SECRET="${TEST_SESSION_SECRET}" \
    -e NGINX_ACCESS_LOG=on \
    ghcr.io/F5GovSolutions/nginx-webssh2:latest

  sleep 10

  # Make a request
  curl -k https://localhost:${TEST_PORT}/ssh/ || true
  sleep 2

  # Access log should contain entries
  run docker exec "${TEST_CONTAINER_PREFIX}-${BATS_TEST_NUMBER}" \
    tail -1 /var/log/nginx/access.log
  assert_success
  assert_output --partial "/ssh/"
}

@test "README Example: WebSSH2 debug logging" {
  docker run -d \
    -p ${TEST_PORT}:443 \
    --name "${TEST_CONTAINER_PREFIX}-${BATS_TEST_NUMBER}" \
    -e WEBSSH2_SESSION_SECRET="${TEST_SESSION_SECRET}" \
    -e DEBUG="webssh2:*" \
    ghcr.io/F5GovSolutions/nginx-webssh2:latest

  sleep 10

  # Check logs for debug output
  run docker logs "${TEST_CONTAINER_PREFIX}-${BATS_TEST_NUMBER}"
  assert_output --partial "webssh2"
}

# ==============================================================================
# Multi-Architecture Tests
# ==============================================================================

@test "README Example: Container supports current architecture" {
  # Get current architecture
  ARCH=$(uname -m)

  docker run -d \
    -p ${TEST_PORT}:443 \
    --name "${TEST_CONTAINER_PREFIX}-${BATS_TEST_NUMBER}" \
    -e WEBSSH2_SESSION_SECRET="${TEST_SESSION_SECRET}" \
    ghcr.io/F5GovSolutions/nginx-webssh2:latest

  sleep 10

  # Verify container architecture matches host
  run docker exec "${TEST_CONTAINER_PREFIX}-${BATS_TEST_NUMBER}" uname -m
  assert_success
  if [[ "${output}" != "${ARCH}" ]]; then
    local compatible=false
    if [[ "${ARCH}" == "arm64" && "${output}" == "aarch64" ]]; then
      compatible=true
    fi
    if [[ "${ARCH}" == "aarch64" && "${output}" == "arm64" ]]; then
      compatible=true
    fi
    if [[ "${compatible}" != "true" ]]; then
      echo "Expected architecture ${ARCH} (or compatible) but got ${output}" >&2
      return 1
    fi
  fi
}

# ==============================================================================
# Service Process Tests
# ==============================================================================

@test "README Example: NGINX process is running" {
  docker run -d \
    -p ${TEST_PORT}:443 \
    --name "${TEST_CONTAINER_PREFIX}-${BATS_TEST_NUMBER}" \
    -e WEBSSH2_SESSION_SECRET="${TEST_SESSION_SECRET}" \
    ghcr.io/F5GovSolutions/nginx-webssh2:latest

  sleep 10

  # Check NGINX is running
  run docker exec "${TEST_CONTAINER_PREFIX}-${BATS_TEST_NUMBER}" pgrep -f "nginx: master"
  assert_success
}

@test "README Example: WebSSH2 Node.js process is running" {
  docker run -d \
    -p ${TEST_PORT}:443 \
    --name "${TEST_CONTAINER_PREFIX}-${BATS_TEST_NUMBER}" \
    -e WEBSSH2_SESSION_SECRET="${TEST_SESSION_SECRET}" \
    ghcr.io/F5GovSolutions/nginx-webssh2:latest

  sleep 10

  # Check Node.js/WebSSH2 is running
  run docker exec "${TEST_CONTAINER_PREFIX}-${BATS_TEST_NUMBER}" pgrep -f "node.*dist/index.js"
  assert_success
}

@test "README Example: s6-overlay supervision is active" {
  docker run -d \
    -p ${TEST_PORT}:443 \
    --name "${TEST_CONTAINER_PREFIX}-${BATS_TEST_NUMBER}" \
    -e WEBSSH2_SESSION_SECRET="${TEST_SESSION_SECRET}" \
    ghcr.io/F5GovSolutions/nginx-webssh2:latest

  sleep 10

  # Check s6-overlay is running
  run docker exec "${TEST_CONTAINER_PREFIX}-${BATS_TEST_NUMBER}" pgrep s6-supervise
  assert_success
}

# ==============================================================================
# Port and Networking Tests
# ==============================================================================

@test "README Example: Container exposes HTTPS port 443" {
  docker run -d \
    -p ${TEST_PORT}:443 \
    --name "${TEST_CONTAINER_PREFIX}-${BATS_TEST_NUMBER}" \
    -e WEBSSH2_SESSION_SECRET="${TEST_SESSION_SECRET}" \
    ghcr.io/F5GovSolutions/nginx-webssh2:latest

  sleep 10

  # Verify port is exposed and accessible
  run curl -k -I https://localhost:${TEST_PORT}/health
  assert_success
  assert_output --partial " 200"
}

# ==============================================================================
# Security Tests
# ==============================================================================

@test "README Example: Container runs as non-root user" {
  docker run -d \
    -p ${TEST_PORT}:443 \
    --name "${TEST_CONTAINER_PREFIX}-${BATS_TEST_NUMBER}" \
    -e WEBSSH2_SESSION_SECRET="${TEST_SESSION_SECRET}" \
    ghcr.io/F5GovSolutions/nginx-webssh2:latest

  sleep 10

  # Check NGINX worker processes run as non-root
  run docker exec "${TEST_CONTAINER_PREFIX}-${BATS_TEST_NUMBER}" \
    sh -c 'pgrep -u nginx -f "nginx: worker"'
  assert_success
}

@test "README Example: Security headers are present" {
  docker run -d \
    -p ${TEST_PORT}:443 \
    --name "${TEST_CONTAINER_PREFIX}-${BATS_TEST_NUMBER}" \
    -e WEBSSH2_SESSION_SECRET="${TEST_SESSION_SECRET}" \
    ghcr.io/F5GovSolutions/nginx-webssh2:latest

  sleep 10

  # Check for security headers on primary application endpoint
  run curl -k -I https://localhost:${TEST_PORT}/ssh/
  assert_success
  assert_output --partial "x-frame-options"
  assert_output --partial "x-content-type-options"
}

# ==============================================================================
# Persistent Session Tests
# ==============================================================================

@test "README Example: Persistent session secret across restarts" {
  PERSISTENT_SECRET="test-persistent-secret-$(date +%s)"

  # Start container with persistent secret
  docker run -d \
    -p ${TEST_PORT}:443 \
    --name "${TEST_CONTAINER_PREFIX}-${BATS_TEST_NUMBER}" \
    -e WEBSSH2_SESSION_SECRET="${PERSISTENT_SECRET}" \
    ghcr.io/F5GovSolutions/nginx-webssh2:latest

  sleep 10

  # Restart container
  docker restart "${TEST_CONTAINER_PREFIX}-${BATS_TEST_NUMBER}"
  sleep 10

  # Verify container is still running with same secret
  run docker ps --filter "name=${TEST_CONTAINER_PREFIX}-${BATS_TEST_NUMBER}" --format "{{.Status}}"
  assert_output --partial "Up"

  run docker exec "${TEST_CONTAINER_PREFIX}-${BATS_TEST_NUMBER}" \
    sh -c 'printenv WEBSSH2_SESSION_SECRET'
  assert_success
  assert_output --partial "${PERSISTENT_SECRET}"
}

# ==============================================================================
# Image Tag Tests
# ==============================================================================

@test "README Example: Latest tag is available" {
  run docker pull ghcr.io/F5GovSolutions/nginx-webssh2:latest
  assert_success
}

@test "README Example: Image metadata includes labels" {
  run docker inspect ghcr.io/F5GovSolutions/nginx-webssh2:latest --format '{{json .Config.Labels}}'
  assert_success
  assert_output --partial "org.opencontainers"
}
