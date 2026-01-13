#!/usr/bin/env bats
# Test suite for Docker Compose deployment examples from README.md

load test_helper

setup() {
  export TEST_COMPOSE_PROJECT="test-nginx-webssh2-${BATS_TEST_NUMBER}"
  export TEST_SESSION_SECRET="$(openssl rand -base64 32)"
  export COMPOSE_PROJECT_NAME="${TEST_COMPOSE_PROJECT}"

  # Create temporary directory for test
  TEST_DIR="$(mktemp -d)"
  export TEST_DIR
  cd "${TEST_DIR}"
}

teardown() {
  # Cleanup compose project
  docker-compose down -v 2>/dev/null || true
  docker compose down -v 2>/dev/null || true

  # Remove test directory
  if [ -n "${TEST_DIR}" ] && [ -d "${TEST_DIR}" ]; then
    rm -rf "${TEST_DIR}"
  fi
}

# ==============================================================================
# Docker Compose Basic Tests
# ==============================================================================

@test "README Example: Docker Compose basic deployment" {
  # Create docker-compose.yml from README example
  cat > docker-compose.yml <<EOF
version: '3.8'

services:
  nginx-webssh2:
    image: ghcr.io/F5GovSolutions/nginx-webssh2:latest
    ports:
      - "8443:443"
    environment:
      WEBSSH2_SESSION_SECRET: "${TEST_SESSION_SECRET}"
      TLS_MODE: self-signed
EOF

  # Start services
  run docker-compose up -d
  assert_success

  # Wait for service to be ready
  sleep 15

  # Check service is running
  run docker-compose ps
  assert_success
  assert_output --partial "Up"

  # Test health endpoint
  run curl -k -f https://localhost:8443/health
  assert_success
}

@test "README Example: Docker Compose with provided certificates" {
  # Generate test certificates
  mkdir -p certs
  generate_test_certs certs

  # Create .env file
  cat > .env <<EOF
SESSION_SECRET=${TEST_SESSION_SECRET}
EOF

  # Create docker-compose.yml from README example
  cat > docker-compose.yml <<EOF
version: '3.8'

services:
  nginx-webssh2:
    image: ghcr.io/F5GovSolutions/nginx-webssh2:latest
    ports:
      - "8443:443"
    environment:
      WEBSSH2_SESSION_SECRET: "\${SESSION_SECRET}"
      TLS_MODE: provided
      FIPS_MODE: disabled
      FIPS_CHECK: false
    volumes:
      - ./certs:/etc/nginx/certs:ro
    restart: unless-stopped
EOF

  # Start services
  run docker-compose up -d
  assert_success

  sleep 15

  # Verify service is running
  run docker-compose ps
  assert_success
  assert_output --partial "Up"
}

@test "README Example: Docker Compose environment variable validation" {
  # Create docker-compose.yml without session secret
  cat > docker-compose.yml <<EOF
version: '3.8'

services:
  nginx-webssh2:
    image: ghcr.io/F5GovSolutions/nginx-webssh2:latest
    ports:
      - "8443:443"
    environment:
      TLS_MODE: self-signed
EOF

  # Start services (container should auto-generate session secret)
  run docker-compose up -d
  assert_success
  sleep 10

  # Check container status (should be running)
  run docker-compose ps
  assert_success
  assert_output --partial "Up"

  # Logs should note the generated session secret
  run docker-compose logs
  assert_success
  assert_output --partial "Generating random session secret"
}

@test "README Example: Docker Compose logs accessible" {
  cat > docker-compose.yml <<EOF
version: '3.8'

services:
  nginx-webssh2:
    image: ghcr.io/F5GovSolutions/nginx-webssh2:latest
    ports:
      - "8443:443"
    environment:
      WEBSSH2_SESSION_SECRET: "${TEST_SESSION_SECRET}"
      TLS_MODE: self-signed
EOF

  docker-compose up -d
  sleep 10

  # Check logs are accessible
  run docker-compose logs
  assert_success
  assert_output --partial "nginx"
}

@test "README Example: Docker Compose with custom NGINX settings" {
  cat > docker-compose.yml <<EOF
version: '3.8'

services:
  nginx-webssh2:
    image: ghcr.io/F5GovSolutions/nginx-webssh2:latest
    ports:
      - "8443:443"
    environment:
      WEBSSH2_SESSION_SECRET: "${TEST_SESSION_SECRET}"
      TLS_MODE: self-signed
      NGINX_ACCESS_LOG: on
      NGINX_RATE_LIMIT: 10r/s
      NGINX_RATE_LIMIT_BURST: 20
EOF

  run docker-compose up -d
  assert_success

  sleep 10

  # Verify container is running
  run docker-compose ps
  assert_success
  assert_output --partial "Up"
}

# ==============================================================================
# Podman Compose Tests (if available)
# ==============================================================================

@test "README Example: Podman Compose compatibility" {
  skip "Requires podman-compose installation"

  cat > docker-compose.yml <<EOF
version: '3.8'

services:
  nginx-webssh2:
    image: ghcr.io/F5GovSolutions/nginx-webssh2:latest
    ports:
      - "8443:443"
    environment:
      WEBSSH2_SESSION_SECRET: "${TEST_SESSION_SECRET}"
      TLS_MODE: self-signed
    security_opt:
      - label=disable
EOF

  # Try podman-compose if available
  if command -v podman-compose &> /dev/null; then
    run podman-compose up -d
    assert_success

    sleep 15

    run podman-compose ps
    assert_success
  fi
}

# ==============================================================================
# Service Restart and Persistence Tests
# ==============================================================================

@test "README Example: Docker Compose service restart" {
  cat > docker-compose.yml <<EOF
version: '3.8'

services:
  nginx-webssh2:
    image: ghcr.io/F5GovSolutions/nginx-webssh2:latest
    ports:
      - "8443:443"
    environment:
      WEBSSH2_SESSION_SECRET: "${TEST_SESSION_SECRET}"
      TLS_MODE: self-signed
EOF

  docker-compose up -d
  sleep 10

  # Restart service
  run docker-compose restart
  assert_success

  sleep 10

  # Verify service is still running
  run docker-compose ps
  assert_success
  assert_output --partial "Up"
}

@test "README Example: Docker Compose graceful stop" {
  cat > docker-compose.yml <<EOF
version: '3.8'

services:
  nginx-webssh2:
    image: ghcr.io/F5GovSolutions/nginx-webssh2:latest
    ports:
      - "8443:443"
    environment:
      WEBSSH2_SESSION_SECRET: "${TEST_SESSION_SECRET}"
      TLS_MODE: self-signed
EOF

  docker-compose up -d
  sleep 10

  # Stop service
  run docker-compose stop
  assert_success

  # Verify service is stopped
  run docker-compose ps
  refute_output --partial "Up"
}

@test "README Example: Docker Compose with debug logging" {
  cat > docker-compose.yml <<EOF
version: '3.8'

services:
  nginx-webssh2:
    image: ghcr.io/F5GovSolutions/nginx-webssh2:latest
    ports:
      - "8443:443"
    environment:
      WEBSSH2_SESSION_SECRET: "${TEST_SESSION_SECRET}"
      TLS_MODE: self-signed
      DEBUG: "webssh2:*"
      NGINX_ACCESS_LOG: on
      NGINX_ERROR_LOG_LEVEL: debug
EOF

  run docker-compose up -d
  assert_success

  sleep 10

  # Check logs contain debug output
  run docker-compose logs
  assert_success
  assert_output --partial "webssh2"
}
