# GitHub Container Registry Workflow Documentation

## Overview

This repository is configured with release-driven CI/CD to build and publish Docker images to GitHub Container Registry (ghcr.io). Releases are orchestrated by release-please, consume the prebuilt WebSSH2 artifact, and produce multi-architecture images tagged from the upstream WebSSH2 version.

## Workflow Triggers

The workflows trigger on:

- **repository_dispatch:webssh2-release** – Created by the upstream WebSSH2 release notifier; runs release-please to open a release PR pinned to that version.
- **Push to main (post-merge)** – release-please finalizes the GitHub Release when a release PR lands.
- **Release publication** – The `publish` workflow downloads the matching WebSSH2 artifact and builds/pushes the container image.
- **Manual trigger** – `publish.yml` can be run on demand with an explicit version.

## Container Registry Details

### Image Location

```bash
ghcr.io/F5GovSolutions/nginx-webssh2
```

### Available Tags

- `latest` - Mirrors the most recent WebSSH2 release
- `v1.0.0` - Specific version release
- `v1.0` - Major.minor version (updates with patches)
- `v1` - Major version (updates with minor/patches)

### Multi-Architecture Support

Images are automatically built for:

- `linux/amd64` - Intel/AMD 64-bit processors
- `linux/arm64` - ARM 64-bit (Apple Silicon, AWS Graviton)

## Setting Up Package Visibility

**IMPORTANT**: After the first workflow run, you need to make the package public:

1. Go to: <https://github.com/orgs/F5GovSolutions/packages/container/nginx-webssh2/settings>
2. Under "Danger Zone", click "Change visibility"
3. Select "Public"
4. Confirm the change

This allows users to pull images without authentication while keeping the repository private.

## Pulling Images

### Public Access (after visibility change)

```bash
# No authentication required
docker pull ghcr.io/F5GovSolutions/nginx-webssh2:latest
docker pull ghcr.io/F5GovSolutions/nginx-webssh2:v1.0.0
```

### Private Access (before visibility change)

```bash
# Login first
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin
docker pull ghcr.io/F5GovSolutions/nginx-webssh2:latest
```

## Triggering Builds

### Automated Flow

1. WebSSH2 publishes a release → the upstream workflow sends `repository_dispatch:webssh2-release` to this repo.
2. `sync-webssh2-release.yml` runs release-please with `release-as=<webssh2 version>` and opens a release PR.
3. Merge the release PR after review.
4. The push to `main` triggers `release-please.yml`, which turns the merged PR into a GitHub Release (tag `vX.Y.Z`).
5. The `release` event fires `publish.yml`, which downloads the matching WebSSH2 artifact, builds multi-arch images, and pushes them to GHCR.

### Manual Trigger

- Use the **Build and Publish Docker Image** workflow → **Run workflow**.
- Supply the WebSSH2 version you want to publish (e.g., `2.4.0`) and set `publish` to `true` to push images.

## Workflow Features

### Security Scanning

Security scanning is currently disabled in the publish workflow. Run Trivy or another scanner ad hoc if you require a vulnerability report before promoting an image.

### Build Caching

- Uses GitHub Actions cache for faster builds
- Docker layer caching enabled
- Multi-stage build optimization

### WebSSH2 Artifact Handling

- `sync-webssh2-release.yml` records the upstream WebSSH2 version in `WEBSSH2_VERSION` via release-please.
- `publish.yml` calls `scripts/fetch-webssh2-release.sh` to download the release tarball and verify its checksum before building the image.

## Monitoring Builds

### View Build Status

1. Go to the Actions tab in GitHub
2. Click on a workflow run to see details
3. View logs for each job step

### Check Package Info

Visit: <https://github.com/orgs/F5GovSolutions/packages/container/package/nginx-webssh2>

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

1. **Artifact download failed**:
   - Ensure `GITHUB_TOKEN` (or a PAT) is available for private releases
   - Confirm the upstream release published `webssh2-<version>.tar.gz` and `.sha256`

2. **Permission denied pushing**:
   - Workflow has correct permissions set
   - GITHUB_TOKEN is used automatically

3. **Package not visible**:
   - Need to manually set to public after first push
   - Check organization package settings

### Testing Locally

Before pushing, test the build:

```bash
git clone https://github.com/F5GovSolutions/nginx-webssh2.git
cd nginx-webssh2

# Pull the WebSSH2 artifact referenced in WEBSSH2_VERSION
./scripts/fetch-webssh2-release.sh "$(cat WEBSSH2_VERSION)"

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
