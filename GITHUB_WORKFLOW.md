# GitHub Container Registry Workflow Documentation

## Overview

This repository is configured with automated CI/CD to build and publish Docker images to GitHub Container Registry (ghcr.io). The workflow provides multi-architecture builds, vulnerability scanning, and automatic versioning.

## Workflow Triggers

The workflow (`.github/workflows/publish.yml`) triggers on:

- **Push to main branch** - Builds and tags as `latest`
- **Version tags** - When you push tags like `v1.0.0`, creates semantic version tags
- **Pull requests** - Builds but doesn't push (for testing)
- **Manual trigger** - Via GitHub Actions UI with optional publish flag
- **Release publication** - When you create a GitHub release

## Container Registry Details

### Image Location

```bash
ghcr.io/f5gov/nginx-webssh2
```

### Available Tags

- `latest` - Latest build from main branch
- `v1.0.0` - Specific version release
- `v1.0` - Major.minor version (updates with patches)
- `v1` - Major version (updates with minor/patches)
- `main-<sha>` - Commit-specific builds
- `pr-<number>` - Pull request preview builds

### Multi-Architecture Support

Images are automatically built for:

- `linux/amd64` - Intel/AMD 64-bit processors
- `linux/arm64` - ARM 64-bit (Apple Silicon, AWS Graviton)

## Setting Up Package Visibility

**IMPORTANT**: After the first workflow run, you need to make the package public:

1. Go to: <https://github.com/orgs/f5gov/packages/container/nginx-webssh2/settings>
2. Under "Danger Zone", click "Change visibility"
3. Select "Public"
4. Confirm the change

This allows users to pull images without authentication while keeping the repository private.

## Pulling Images

### Public Access (after visibility change)

```bash
# No authentication required
docker pull ghcr.io/f5gov/nginx-webssh2:latest
docker pull ghcr.io/f5gov/nginx-webssh2:v1.0.0
```

### Private Access (before visibility change)

```bash
# Login first
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin
docker pull ghcr.io/f5gov/nginx-webssh2:latest
```

## Triggering Builds

### Automatic Triggers

1. **Every push to main**:

   ```bash
   git push origin main
   # Automatically builds and tags as 'latest'
   ```

2. **Creating a version tag**:

   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   # Creates v1.0.0, v1.0, v1, and latest tags
   ```

3. **Creating a release**:
   - Go to GitHub Releases
   - Click "Create a new release"
   - Choose a tag (e.g., v1.0.0)
   - Publish release
   - Workflow automatically runs

### Manual Trigger

1. Go to Actions tab in GitHub
2. Select "Build and Publish Docker Image" workflow
3. Click "Run workflow"
4. Choose branch and whether to publish
5. Click "Run workflow" button

## Workflow Features

### Security Scanning

Every build includes:

- **Trivy vulnerability scanning** - Scans for CVEs and security issues
- **SARIF upload** - Results appear in GitHub Security tab
- **Build attestations** - Cryptographic proof of build provenance

### Build Caching

- Uses GitHub Actions cache for faster builds
- Docker layer caching enabled
- Multi-stage build optimization

### Submodule Support

The workflow automatically:

- Checks out the repository with `--recursive`
- Fetches the webssh2 submodule from the `newmain` branch
- Includes all submodule content in the build

## Monitoring Builds

### View Build Status

1. Go to the Actions tab in GitHub
2. Click on a workflow run to see details
3. View logs for each job step

### Check Package Info

Visit: <https://github.com/orgs/f5gov/packages/container/package/nginx-webssh2>

This shows:

- All available tags
- Download statistics
- Package size
- Recent versions

### Security Alerts

Check the Security tab for:

- Vulnerability scan results
- Dependabot alerts
- Security advisories

## Troubleshooting

### Build Failures

Common issues and solutions:

1. **Submodule not found**:
   - Ensure `.gitmodules` is committed
   - Check submodule branch is `newmain`

2. **Permission denied pushing**:
   - Workflow has correct permissions set
   - GITHUB_TOKEN is used automatically

3. **Package not visible**:
   - Need to manually set to public after first push
   - Check organization package settings

### Testing Locally

Before pushing, test the build:

```bash
# Clone with submodules
git clone --recursive https://github.com/f5gov/nginx-webssh2.git
cd nginx-webssh2

# Test build
docker build -t nginx-webssh2:test .

# Test run
docker run -p 443:443 -e WEBSSH2_SESSION_SECRET="test" nginx-webssh2:test
```

## Best Practices

1. **Versioning**:
   - Use semantic versioning (v1.0.0)
   - Tag releases for production deployments
   - Use `latest` for development/testing

2. **Security**:
   - Review vulnerability scan results
   - Keep base images updated
   - Don't commit secrets

3. **Testing**:
   - Test builds locally first
   - Use PR builds for validation
   - Check multi-arch compatibility

## Support

For workflow issues:

- Check Actions tab for logs
- Review this documentation
- Open an issue in the repository

For registry issues:

- Check GitHub Status page
- Verify package visibility settings
- Ensure proper authentication (if private)
