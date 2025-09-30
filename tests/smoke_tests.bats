#!/usr/bin/env bats
# Quick smoke tests for nginx-webssh2 container
# Fast validation of core functionality

load test_helper

setup() {
  export TEST_SESSION_SECRET="$(openssl rand -base64 32)"
  export TEST_CONTAINER_NAME="nginx-webssh2-smoke-${BATS_TEST_NUMBER}"
  export TEST_PORT=8443
}

teardown() {
  docker rm -f "${TEST_CONTAINER_NAME}" 2>/dev/null || true
}

@test "Smoke: Container starts with required environment variable" {
  # Start container
  run docker run -d \
    -p ${TEST_PORT}:443 \
    --name "${TEST_CONTAINER_NAME}" \
    -e WEBSSH2_SESSION_SECRET="${TEST_SESSION_SECRET}" \
    ghcr.io/f5gov/nginx-webssh2:latest

  assert_success

  # Wait briefly
  sleep 5

  # Check container is running
  run docker ps --filter "name=${TEST_CONTAINER_NAME}" --format "{{.Status}}"
  assert_success
  assert_output --partial "Up"
}

@test "Smoke: Image has correct labels" {
  run docker inspect ghcr.io/f5gov/nginx-webssh2:latest --format '{{json .Config.Labels}}'
  assert_success
  assert_output --partial "org.opencontainers"
}

@test "Smoke: Container exposes port 443" {
  docker run -d \
    -p ${TEST_PORT}:443 \
    --name "${TEST_CONTAINER_NAME}" \
    -e WEBSSH2_SESSION_SECRET="${TEST_SESSION_SECRET}" \
    ghcr.io/f5gov/nginx-webssh2:latest

  sleep 8

  # Check port mapping
  run docker port "${TEST_CONTAINER_NAME}" 443
  assert_success
  assert_output --partial "${TEST_PORT}"
}

@test "Smoke: NGINX process is running" {
  docker run -d \
    -p ${TEST_PORT}:443 \
    --name "${TEST_CONTAINER_NAME}" \
    -e WEBSSH2_SESSION_SECRET="${TEST_SESSION_SECRET}" \
    ghcr.io/f5gov/nginx-webssh2:latest

  sleep 8

  # Check for NGINX process
  run docker exec "${TEST_CONTAINER_NAME}" pgrep nginx
  assert_success
}

@test "Smoke: Container has correct base image" {
  run docker inspect ghcr.io/f5gov/nginx-webssh2:latest --format '{{.Os}}/{{.Architecture}}'
  assert_success
  # Should be linux/amd64 or linux/arm64
  [[ "$output" =~ linux/(amd64|arm64) ]]
}