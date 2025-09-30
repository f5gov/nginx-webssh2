#!/usr/bin/env bash
# Test helper functions for BATS tests

# Load BATS support libraries if available
if [ -f "/usr/local/lib/bats-support/load.bash" ]; then
  load '/usr/local/lib/bats-support/load'
fi

if [ -f "/usr/local/lib/bats-assert/load.bash" ]; then
  load '/usr/local/lib/bats-assert/load'
fi

# Fallback assert functions if bats-assert is not available
if ! command -v assert_success &> /dev/null; then
  assert_success() {
    if [ "$status" -ne 0 ]; then
      echo "Expected success but got status: $status"
      echo "Output: $output"
      return 1
    fi
  }

  assert_failure() {
    if [ "$status" -eq 0 ]; then
      echo "Expected failure but got success"
      echo "Output: $output"
      return 1
    fi
  }

  assert_output() {
    local expected
    if [ "$1" = "--partial" ]; then
      expected="$2"
      if [[ ! "$output" =~ $expected ]]; then
        echo "Expected output to contain: $expected"
        echo "Actual output: $output"
        return 1
      fi
    else
      expected="$1"
      if [ "$output" != "$expected" ]; then
        echo "Expected output: $expected"
        echo "Actual output: $output"
        return 1
      fi
    fi
  }

  refute_output() {
    local unexpected
    if [ "$1" = "--partial" ]; then
      unexpected="$2"
      if [[ "$output" =~ $unexpected ]]; then
        echo "Expected output NOT to contain: $unexpected"
        echo "Actual output: $output"
        return 1
      fi
    else
      unexpected="$1"
      if [ "$output" = "$unexpected" ]; then
        echo "Expected output NOT to be: $unexpected"
        return 1
      fi
    fi
  }
fi

# Helper: Wait for container to be healthy
wait_for_container_health() {
  local container_name="$1"
  local max_wait="${2:-30}"
  local count=0

  while [ $count -lt $max_wait ]; do
    if docker ps --filter "name=${container_name}" --format "{{.Status}}" | grep -q "Up"; then
      return 0
    fi
    sleep 1
    ((count++))
  done

  echo "Container ${container_name} did not become healthy within ${max_wait} seconds"
  return 1
}

# Helper: Wait for port to be available
wait_for_port() {
  local port="$1"
  local max_wait="${2:-30}"
  local count=0

  while [ $count -lt $max_wait ]; do
    if nc -z localhost "$port" 2>/dev/null; then
      return 0
    fi
    sleep 1
    ((count++))
  done

  echo "Port ${port} did not become available within ${max_wait} seconds"
  return 1
}

# Helper: Clean up all test containers
cleanup_test_containers() {
  docker ps -a --filter "name=nginx-webssh2-test" --format "{{.Names}}" | \
    xargs -r docker rm -f 2>/dev/null || true
}

# Helper: Generate test certificates
generate_test_certs() {
  local cert_dir="$1"
  mkdir -p "$cert_dir"

  openssl req -x509 -nodes -days 1 -newkey rsa:2048 \
    -keyout "${cert_dir}/key.pem" \
    -out "${cert_dir}/cert.pem" \
    -subj "/CN=test.localhost/O=Test/C=US" \
    2>/dev/null
}

# Helper: Check if Docker is available
check_docker() {
  if ! command -v docker &> /dev/null; then
    echo "Docker is not available"
    return 1
  fi

  if ! docker info &> /dev/null; then
    echo "Docker daemon is not running"
    return 1
  fi

  return 0
}

# Helper: Pull image if not present
ensure_image() {
  local image="$1"
  if ! docker image inspect "$image" &> /dev/null; then
    docker pull "$image" || return 1
  fi
  return 0
}

# Helper: Get container logs with context
get_container_logs() {
  local container_name="$1"
  local lines="${2:-50}"

  echo "=== Container Logs for ${container_name} ==="
  docker logs --tail "$lines" "$container_name" 2>&1
  echo "=== End Container Logs ==="
}

# Helper: Check if container is running
is_container_running() {
  local container_name="$1"
  docker ps --filter "name=${container_name}" --format "{{.Names}}" | grep -q "^${container_name}$"
}

# Helper: Get container exit code
get_container_exit_code() {
  local container_name="$1"
  docker inspect "$container_name" --format='{{.State.ExitCode}}' 2>/dev/null || echo "255"
}

# Helper: Test SSL/TLS connection
test_ssl_connection() {
  local host="${1:-localhost}"
  local port="${2:-443}"
  local timeout="${3:-5}"

  timeout "$timeout" openssl s_client -connect "${host}:${port}" -showcerts </dev/null 2>&1 | \
    grep -q "Verify return code: 0" && return 0 || return 1
}

# Helper: Make HTTPS request with retry
curl_with_retry() {
  local url="$1"
  local max_retries="${2:-5}"
  local retry_delay="${3:-2}"
  local count=0

  while [ $count -lt $max_retries ]; do
    if curl -k -f -s "$url" &>/dev/null; then
      return 0
    fi
    sleep "$retry_delay"
    ((count++))
  done

  return 1
}

# Helper: Verify environment variable in container
check_container_env() {
  local container_name="$1"
  local env_var="$2"
  local expected_value="$3"

  local actual_value
  actual_value=$(docker exec "$container_name" printenv "$env_var" 2>/dev/null)

  if [ -z "$expected_value" ]; then
    # Just check if variable exists
    [ -n "$actual_value" ]
  else
    # Check if value matches
    [ "$actual_value" = "$expected_value" ]
  fi
}

# Helper: Check if process is running in container
check_container_process() {
  local container_name="$1"
  local process_pattern="$2"

  docker exec "$container_name" pgrep -f "$process_pattern" &>/dev/null
}

# Helper: Get free port for testing
get_free_port() {
  local port
  port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()' 2>/dev/null)

  if [ -z "$port" ]; then
    # Fallback: use a high random port
    port=$((30000 + RANDOM % 10000))
  fi

  echo "$port"
}

# Export all functions
export -f wait_for_container_health
export -f wait_for_port
export -f cleanup_test_containers
export -f generate_test_certs
export -f check_docker
export -f ensure_image
export -f get_container_logs
export -f is_container_running
export -f get_container_exit_code
export -f test_ssl_connection
export -f curl_with_retry
export -f check_container_env
export -f check_container_process
export -f get_free_port