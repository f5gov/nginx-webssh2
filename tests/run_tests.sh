#!/usr/bin/env bash
# Test runner for nginx-webssh2 README deployment tests
# This script runs all BATS tests for container deployment validation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_info() {
  echo -e "${BLUE}[INFO]${NC} $*"
}

print_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $*"
}

print_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $*"
}

print_error() {
  echo -e "${RED}[ERROR]${NC} $*"
}

# Check prerequisites
check_prerequisites() {
  local missing_deps=()

  print_info "Checking prerequisites..."

  # Check for Docker
  if ! command -v docker &> /dev/null; then
    missing_deps+=("docker")
  fi

  # Check if Docker daemon is running
  if ! docker info &> /dev/null; then
    print_error "Docker daemon is not running"
    exit 1
  fi

  # Check for BATS
  if ! command -v bats &> /dev/null; then
    print_warning "BATS is not installed. Tests will not run."
    print_info "Install BATS:"
    print_info "  - macOS: brew install bats-core"
    print_info "  - Linux: https://bats-core.readthedocs.io/en/stable/installation.html"
    missing_deps+=("bats")
  fi

  # Check for docker-compose
  if ! command -v docker-compose &> /dev/null && ! command -v docker &> /dev/null; then
    print_warning "docker-compose not found (optional for compose tests)"
  fi

  if [ ${#missing_deps[@]} -gt 0 ]; then
    print_error "Missing required dependencies: ${missing_deps[*]}"
    exit 1
  fi

  print_success "All prerequisites met"
}

# Pull the latest image
pull_image() {
  local image="ghcr.io/f5gov/nginx-webssh2:latest"

  print_info "Pulling container image: ${image}"

  if docker pull "$image"; then
    print_success "Image pulled successfully"
  else
    print_error "Failed to pull image: ${image}"
    exit 1
  fi
}

# Clean up any existing test containers
cleanup_test_containers() {
  print_info "Cleaning up existing test containers..."

  local containers
  containers=$(docker ps -a --filter "name=nginx-webssh2-test" --format "{{.Names}}" | tr '\n' ' ')

  if [ -n "$containers" ]; then
    # shellcheck disable=SC2086
    docker rm -f $containers &>/dev/null || true
    print_success "Cleaned up test containers"
  else
    print_info "No test containers to clean up"
  fi
}

# Run BATS tests
run_bats_tests() {
  local test_file="$1"
  local test_name="$2"

  if [ ! -f "$test_file" ]; then
    print_error "Test file not found: $test_file"
    return 1
  fi

  print_info "Running ${test_name}..."
  echo ""

  if bats "$test_file"; then
    echo ""
    print_success "${test_name} completed"
    return 0
  else
    echo ""
    print_error "${test_name} failed"
    return 1
  fi
}

# Main test execution
main() {
  local failed_tests=0
  local total_tests=0

  echo ""
  echo "=========================================="
  echo "  nginx-webssh2 README Deployment Tests"
  echo "=========================================="
  echo ""

  # Check prerequisites
  check_prerequisites

  # Pull latest image
  pull_image

  # Clean up before tests
  cleanup_test_containers

  echo ""
  echo "=========================================="
  echo "  Running Test Suites"
  echo "=========================================="
  echo ""

  # Run smoke tests first (fast validation)
  if [ -f "${SCRIPT_DIR}/smoke_tests.bats" ]; then
    total_tests=$((total_tests + 1))
    if run_bats_tests "${SCRIPT_DIR}/smoke_tests.bats" "Smoke Tests (Quick Validation)"; then
      print_success "Smoke tests passed!"
    else
      failed_tests=$((failed_tests + 1))
      print_error "Smoke tests failed - skipping remaining tests"
      cleanup_test_containers
      echo ""
      echo "=========================================="
      echo "  Test Summary"
      echo "=========================================="
      echo ""
      echo "Smoke tests failed. Fix these before running full test suite."
      return 1
    fi
    echo ""
  else
    print_warning "smoke_tests.bats not found, skipping smoke tests"
  fi

  # Run deployment tests
  total_tests=$((total_tests + 1))
  if ! run_bats_tests "${SCRIPT_DIR}/README_deployment_tests.bats" "README Deployment Tests"; then
    failed_tests=$((failed_tests + 1))
  fi

  echo ""

  # Run docker-compose tests
  total_tests=$((total_tests + 1))
  if ! run_bats_tests "${SCRIPT_DIR}/docker_compose_tests.bats" "Docker Compose Tests"; then
    failed_tests=$((failed_tests + 1))
  fi

  echo ""

  # Clean up after tests
  cleanup_test_containers

  # Print summary
  echo ""
  echo "=========================================="
  echo "  Test Summary"
  echo "=========================================="
  echo ""
  echo "Total test suites: ${total_tests}"
  echo "Passed: $((total_tests - failed_tests))"
  echo "Failed: ${failed_tests}"
  echo ""

  if [ $failed_tests -eq 0 ]; then
    print_success "All tests passed!"
    return 0
  else
    print_error "${failed_tests} test suite(s) failed"
    return 1
  fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --skip-pull)
      SKIP_PULL=true
      shift
      ;;
    --no-cleanup)
      NO_CLEANUP=true
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --skip-pull     Skip pulling the latest container image"
      echo "  --no-cleanup    Don't clean up test containers after tests"
      echo "  --help, -h      Show this help message"
      echo ""
      exit 0
      ;;
    *)
      print_error "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Override functions if flags set
if [ "${SKIP_PULL:-false}" = "true" ]; then
  pull_image() {
    print_info "Skipping image pull (--skip-pull)"
  }
fi

if [ "${NO_CLEANUP:-false}" = "true" ]; then
  cleanup_test_containers() {
    print_info "Skipping cleanup (--no-cleanup)"
  }
fi

# Run main function
main
exit $?