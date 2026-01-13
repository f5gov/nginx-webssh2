# Quick Start Guide

## TL;DR - Run Tests Now

```bash
# 1. Install BATS (one-time setup)
brew install bats-core  # macOS
# OR
sudo apt-get install bats  # Linux

# 2. Run smoke tests (fast - 30 seconds)
cd tests
bats smoke_tests.bats

# 3. Run full test suite (slow - 10-15 minutes)
./run_tests.sh
```

## What Gets Tested

### ✅ Smoke Tests (Fast - ~30 seconds)
Basic validation that the container works:
- Container starts with `WEBSSH2_SESSION_SECRET`
- Image has correct labels
- Port 443 is exposed
- NGINX process is running
- Correct architecture (linux/amd64 or linux/arm64)

**Run**: `bats smoke_tests.bats`

### ✅ README Deployment Tests (Comprehensive - ~10 minutes)
Validates all deployment examples from README.md:
- 21 test scenarios
- All environment variables
- TLS/SSL configurations
- Health checks
- Logging
- Security features
- Process supervision

**Run**: `bats README_deployment_tests.bats`

### ✅ Docker Compose Tests (~5 minutes)
Tests Docker Compose deployment patterns:
- 9 test scenarios
- Basic deployment
- Provided certificates
- Environment validation
- Service management

**Run**: `bats docker_compose_tests.bats`

## Test Output

### Success
```
1..5
ok 1 Smoke: Container starts with required environment variable
ok 2 Smoke: Image has correct labels
ok 3 Smoke: Container exposes port 443
ok 4 Smoke: NGINX process is running
ok 5 Smoke: Container has correct base image
```

### Failure
```
1..5
ok 1 Smoke: Container starts with required environment variable
not ok 2 Smoke: Image has correct labels
# (from function `assert_output' in file test_helper.bash, line 38)
#   `assert_output --partial "org.opencontainers"' failed
# Expected output to contain: org.opencontainers
# Actual output: {}
```

## Common Issues

### "BATS not found"
```bash
# Install BATS
brew install bats-core  # macOS
sudo apt-get install bats  # Linux
```

### "Docker daemon not running"
```bash
# Start Docker
open -a Docker  # macOS
sudo systemctl start docker  # Linux
```

### "Port already in use"
Tests use port 8443 by default. If in use:
```bash
# Check what's using the port
lsof -i :8443

# Stop the conflicting service or kill test containers
docker ps -a | grep nginx-webssh2-test
docker rm -f $(docker ps -aq --filter "name=nginx-webssh2-test")
```

### Tests taking too long
This is normal! Container tests are slow because they:
- Pull images (if needed)
- Start containers (10 seconds each)
- Wait for services to initialize
- Test functionality
- Clean up

**Total time**:
- Smoke tests: ~30 seconds
- Full suite: ~15 minutes

## Running Specific Tests

```bash
# Run just one test by name
bats smoke_tests.bats -f "Container starts"

# Run tests with verbose output
bats -v smoke_tests.bats

# Run tests with TAP output (for CI)
bats --tap smoke_tests.bats

# Run tests with timing
bats --timing smoke_tests.bats
```

## Development Workflow

### 1. Quick Validation
```bash
# Run smoke tests first (30 seconds)
bats smoke_tests.bats
```

### 2. Test Specific Feature
```bash
# Test just health checks
bats README_deployment_tests.bats -f "health"

# Test just TLS
bats README_deployment_tests.bats -f "TLS"

# Test just logging
bats README_deployment_tests.bats -f "logging"
```

### 3. Full Validation
```bash
# Run everything (15 minutes)
./run_tests.sh
```

## CI/CD Usage

### GitHub Actions
```yaml
- name: Run smoke tests
  run: |
    cd tests
    bats smoke_tests.bats

- name: Run full test suite
  run: |
    cd tests
    ./run_tests.sh --skip-pull
  timeout-minutes: 20
```

### GitLab CI
```yaml
test:
  script:
    - cd tests
    - bats smoke_tests.bats
    - ./run_tests.sh --skip-pull
  timeout: 20m
```

## Understanding Test Times

| Test Suite | Tests | Duration | Why |
|------------|-------|----------|-----|
| Smoke | 5 | ~30s | Minimal container validation |
| README | 21 | ~10m | Full deployment scenarios, each starts container |
| Compose | 9 | ~5m | Docker Compose lifecycle tests |
| **Total** | **35** | **~15m** | Complete validation |

Each test that starts a container adds ~10-15 seconds for:
- Container startup (3-5s)
- Service initialization (5-10s)
- Health checks (2-5s)

## Debugging Failed Tests

### Get container logs
```bash
# Find test containers
docker ps -a | grep nginx-webssh2-test

# View logs
docker logs nginx-webssh2-test-3

# Execute commands in container
docker exec nginx-webssh2-test-3 ps aux
docker exec nginx-webssh2-test-3 /usr/local/bin/healthcheck.sh
```

### Run test with keep-alive
```bash
# Run tests but don't cleanup
./run_tests.sh --no-cleanup

# Then inspect the containers
docker ps -a | grep test
```

### Manual container test
```bash
# Start container manually
docker run -d -p 8443:443 --name manual-test \
  -e WEBSSH2_SESSION_SECRET="$(openssl rand -base64 32)" \
  ghcr.io/F5GovSolutions/nginx-webssh2:latest

# Wait and test
sleep 10
curl -k https://localhost:8443/health

# Check logs
docker logs manual-test

# Cleanup
docker rm -f manual-test
```

## Next Steps

1. ✅ **Run smoke tests** - Validate basic functionality
2. 📚 **Read [tests/README.md](README.md)** - Complete documentation
3. 🧪 **Run full suite** - When you have 15 minutes
4. 🔧 **Debug failures** - Use commands above

## Getting Help

- **Test documentation**: [tests/README.md](README.md)
- **Main documentation**: [README.md](../README.md)
- **Build guide**: [docs/BUILD.md](../docs/BUILD.md)
- **Project guide**: [CLAUDE.md](../CLAUDE.md)