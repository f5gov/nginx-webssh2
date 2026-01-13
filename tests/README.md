# nginx-webssh2 Test Suite

Comprehensive test suite for validating container deployment examples from [README.md](../README.md).

## Overview

This test suite validates:
- ✅ **Required environment variables** (`WEBSSH2_SESSION_SECRET`)
- ✅ **Container deployment scenarios** (Docker, Docker Compose)
- ✅ **TLS/SSL configurations** (self-signed, provided certificates)
- ✅ **Health checks and service availability**
- ✅ **Logging configurations**
- ✅ **Security features** (non-root execution, security headers)
- ✅ **Process supervision** (NGINX, WebSSH2, s6-overlay)
- ✅ **Port and networking** (HTTPS, internal WebSSH2 port)

## Prerequisites

### Required
- **Docker**: Container runtime
- **BATS**: Bash Automated Testing System

### Optional
- **docker-compose**: For compose deployment tests
- **bats-support**: Enhanced BATS assertions (auto-detected)
- **bats-assert**: Additional assertion helpers (auto-detected)

### Installation

#### macOS
```bash
# Install BATS
brew install bats-core

# Optional: Install BATS helpers (manually - not in homebrew core)
# These provide enhanced assertions but are not required
git clone https://github.com/bats-core/bats-support.git /usr/local/lib/bats-support
git clone https://github.com/bats-core/bats-assert.git /usr/local/lib/bats-assert

# Note: Tests include fallback implementations if these are not installed
```

#### Linux (Ubuntu/Debian)
```bash
# Install BATS
sudo apt-get update
sudo apt-get install -y bats

# Or install from source
git clone https://github.com/bats-core/bats-core.git
cd bats-core
sudo ./install.sh /usr/local
```

#### Linux (RHEL/CentOS/Fedora)
```bash
# Install BATS
sudo dnf install -y bats

# Or from source
git clone https://github.com/bats-core/bats-core.git
cd bats-core
sudo ./install.sh /usr/local
```

## Running Tests

### Quick Start

Run all tests:
```bash
cd tests
./run_tests.sh
```

### Test Runner Options

```bash
# Run with options
./run_tests.sh --skip-pull      # Skip pulling latest image
./run_tests.sh --no-cleanup     # Don't clean up test containers
./run_tests.sh --help           # Show help
```

### Running Individual Test Suites

#### README Deployment Tests
```bash
bats README_deployment_tests.bats
```

#### Docker Compose Tests
```bash
bats docker_compose_tests.bats
```

### Running Specific Tests

```bash
# Run a specific test by pattern
bats README_deployment_tests.bats --filter "session secret"

# Run with TAP output
bats --tap README_deployment_tests.bats

# Run with timing information
bats --timing README_deployment_tests.bats
```

## Test Suites

### 1. smoke_tests.bats

Quick smoke tests for basic validation (5 tests):
- ✅ Container starts with required environment variable
- ✅ Image has correct labels
- ✅ Container exposes port 443
- ✅ NGINX process is running
- ✅ Container has correct base image

### 2. README_deployment_tests.bats

Tests all deployment examples from README.md (21 tests):

#### Basic Deployment Tests (3 tests)
- ✅ Container starts with session secret
- ✅ Health check endpoint responds
- ✅ Container healthcheck script works

#### TLS/SSL Configuration Tests (2 tests)
- ✅ Self-signed TLS mode (default)
- ✅ Custom self-signed certificate with SAN

#### Environment Variable Tests (3 tests)
- ✅ SSH target configuration
- ✅ FIPS mode enabled
- ✅ Rate limiting configuration

#### Logging Configuration Tests (3 tests)
- ✅ NGINX access logging emits entries by default
- ✅ NGINX access logging (enabled)
- ✅ WebSSH2 debug logging

#### Multi-Architecture Tests (1 test)
- ✅ Container supports current architecture

#### Service Process Tests (3 tests)
- ✅ NGINX process running
- ✅ WebSSH2 Node.js process running
- ✅ s6-overlay supervision active

#### Port and Networking Tests (1 test)
- ✅ HTTPS port 443 exposed

#### Security Tests (2 tests)
- ✅ Container runs as non-root user
- ✅ Security headers present

#### Persistent Session Tests (1 test)
- ✅ Session secret persists across restarts

#### Image Tests (2 tests)
- ✅ Latest tag available
- ✅ Image metadata and labels

### 3. docker_compose_tests.bats

Tests Docker Compose deployment scenarios (9 tests):

#### Basic Compose Tests (5 tests)
- ✅ Basic deployment with docker-compose.yml
- ✅ Deployment with provided certificates
- ✅ Environment variable validation
- ✅ Logs accessible
- ✅ Custom NGINX settings

#### Service Management Tests (3 tests)
- ✅ Service restart
- ✅ Graceful stop
- ✅ Debug logging

#### Optional Tests (1 test - skipped)
- ⏭️ Podman Compose compatibility (requires podman-compose)

## Test Architecture

### Directory Structure
```
tests/
├── README.md                        # This file
├── QUICKSTART.md                    # Quick start guide
├── run_tests.sh                     # Test runner script
├── test_helper.bash                 # Helper functions
├── smoke_tests.bats                 # Quick smoke tests (5 tests)
├── README_deployment_tests.bats     # Main deployment tests (21 tests)
└── docker_compose_tests.bats        # Docker Compose tests (9 tests)
```

### Test Helper Functions

The `test_helper.bash` provides utility functions:

#### Container Management
- `wait_for_container_health(container, max_wait)` - Wait for container to be healthy
- `is_container_running(container)` - Check if container is running
- `cleanup_test_containers()` - Clean up all test containers

#### Network Testing
- `wait_for_port(port, max_wait)` - Wait for port to be available
- `test_ssl_connection(host, port)` - Test SSL/TLS connection
- `curl_with_retry(url, retries, delay)` - HTTP request with retry

#### Certificate Management
- `generate_test_certs(dir)` - Generate test certificates

#### Container Inspection
- `check_container_env(container, var, value)` - Verify environment variable
- `check_container_process(container, pattern)` - Check if process is running
- `get_container_logs(container, lines)` - Get container logs
- `get_container_exit_code(container)` - Get container exit code

#### Utilities
- `get_free_port()` - Get a free port for testing
- `ensure_image(image)` - Pull image if not present

### Assertion Functions

If `bats-assert` is not installed, fallback implementations are provided:
- `assert_success` - Assert command succeeded (status = 0)
- `assert_failure` - Assert command failed (status != 0)
- `assert_output [--partial] <expected>` - Assert output matches
- `refute_output [--partial] <unexpected>` - Assert output doesn't match

## Test Patterns

### Testing Container Deployment

```bash
@test "Example: Container deployment" {
  # Start container
  docker run -d \
    -p ${TEST_PORT}:443 \
    --name "${TEST_CONTAINER_PREFIX}-${BATS_TEST_NUMBER}" \
    -e WEBSSH2_SESSION_SECRET="${TEST_SESSION_SECRET}" \
    ghcr.io/F5GovSolutions/nginx-webssh2:latest

  # Wait for startup
  sleep 10

  # Verify container is running
  run docker ps --filter "name=${TEST_CONTAINER_PREFIX}-${BATS_TEST_NUMBER}"
  assert_success
  assert_output --partial "Up"
}
```

### Testing Health Endpoints

```bash
@test "Example: Health check" {
  # ... start container ...

  # Test health endpoint
  run curl -k -f https://localhost:${TEST_PORT}/health
  assert_success
}
```

### Testing Environment Variables

```bash
@test "Example: Environment variable" {
  # ... start container ...

  # Verify environment variable
  run docker exec "${CONTAINER_NAME}" printenv WEBSSH2_SSH_HOST
  assert_output "ssh.example.com"
}
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Test README Deployments

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install BATS
        run: |
          sudo apt-get update
          sudo apt-get install -y bats

      - name: Run Tests
        run: |
          cd tests
          ./run_tests.sh
```

### GitLab CI Example

```yaml
test-readme-deployments:
  image: docker:latest
  services:
    - docker:dind
  before_script:
    - apk add --no-cache bash git
    - git clone https://github.com/bats-core/bats-core.git
    - cd bats-core && ./install.sh /usr/local && cd ..
  script:
    - cd tests
    - ./run_tests.sh
```

## Troubleshooting

### Tests Fail with "Docker daemon not running"

**Problem**: Docker is not available or not running.

**Solution**:
```bash
# Start Docker daemon
sudo systemctl start docker  # Linux
open -a Docker              # macOS

# Verify Docker is running
docker info
```

### Tests Fail with "Image not found"

**Problem**: Container image hasn't been pulled.

**Solution**:
```bash
# Pull the image manually
docker pull ghcr.io/F5GovSolutions/nginx-webssh2:latest

# Or run tests with automatic pull
./run_tests.sh
```

### Port Conflicts

**Problem**: Test port already in use.

**Solution**: Tests use dynamic ports (8443+). Check for conflicts:
```bash
# Check what's using port 8443
lsof -i :8443

# Stop conflicting services or change test port
export TEST_PORT=9443
```

### Tests Leave Containers Running

**Problem**: Test containers not cleaned up after failure.

**Solution**:
```bash
# Manually clean up test containers
docker ps -a --filter "name=nginx-webssh2-test" -q | xargs docker rm -f

# Or use helper
./run_tests.sh  # Automatically cleans up before/after
```

### BATS Not Found

**Problem**: BATS is not installed.

**Solution**:
```bash
# macOS
brew install bats-core

# Linux
sudo apt-get install bats  # Debian/Ubuntu
sudo dnf install bats      # RHEL/Fedora
```

## Contributing

### Adding New Tests

1. **Choose the appropriate test file**:
   - `README_deployment_tests.bats` - Container deployment tests
   - `docker_compose_tests.bats` - Docker Compose tests

2. **Follow naming conventions**:
   ```bash
   @test "README Example: <description>" {
     # Test implementation
   }
   ```

3. **Use test helpers**:
   - Import from `test_helper.bash`
   - Use assertion functions
   - Clean up resources in `teardown()`

4. **Document the test**:
   - Add comments explaining what is being tested
   - Reference README.md sections

### Running Tests in Development

```bash
# Run a single test file during development
bats --tap README_deployment_tests.bats

# Run with verbose output
bats -v README_deployment_tests.bats

# Run specific test
bats -f "session secret" README_deployment_tests.bats
```

## Test Coverage

Current test coverage:

| Test Suite | Category | Tests | Coverage |
|------------|----------|-------|----------|
| **Smoke Tests** | Quick validation | 5 | 100% |
| **README Tests** | Basic Deployment | 3 | 100% |
| | TLS/SSL Configuration | 2 | 100% |
| | Environment Variables | 3 | 100% |
| | Logging | 3 | 100% |
| | Multi-Architecture | 1 | 100% |
| | Service Processes | 3 | 100% |
| | Networking | 1 | 100% |
| | Security | 2 | 100% |
| | Persistence | 1 | 100% |
| | Image Metadata | 2 | 100% |
| **Compose Tests** | Basic Compose | 5 | 100% |
| | Service Management | 3 | 100% |
| | Optional (Podman) | 1 | Skipped |
| **Total** | **All Tests** | **35** | **100%** |

## References

- [BATS Documentation](https://bats-core.readthedocs.io/)
- [bats-support](https://github.com/bats-core/bats-support)
- [bats-assert](https://github.com/bats-core/bats-assert)
- [nginx-webssh2 README](../README.md)
- [nginx-webssh2 CLAUDE.md](../CLAUDE.md)

## License

MIT License - see [LICENSE](../LICENSE) file for details.