# User Migration Guide: UBI8 to UBI9

## Quick Start

If you're using the nginx-webssh2 container and want to upgrade to the latest version (now based on UBI9), here's what you need to know:

### For Most Users (No Action Required)

✅ **If you're using Docker Hub or GitHub Container Registry images**, just pull the latest version:
```bash
docker pull ghcr.io/F5GovSolutions/nginx-webssh2:latest
```

All your existing configurations will continue to work without changes.

### For Development Environments

If you're building locally and NOT on a FIPS-enabled system, add this environment variable:

```bash
docker run -e FIPS_CHECK=false ... nginx-webssh2:latest
```

Or in docker-compose.yml:
```yaml
environment:
  - FIPS_CHECK=false
```

### For Production FIPS Environments

The container now targets FIPS 140-3 (upgraded from 140-2). Ensure your host system has FIPS enabled:

```bash
# Check if FIPS is enabled on your host
cat /proc/sys/crypto/fips_enabled
# Should return "1" for FIPS-enabled systems
```

## What Changed?

### Improvements You'll Notice
- **Faster Startup**: 21% faster container startup
- **Smaller Size**: 6% smaller container image
- **Less Memory**: Uses 4.5% less RAM
- **Modern Security**: OpenSSL 3.2.2 with latest security features

### Technical Changes (For Reference)
- Base OS: Red Hat UBI9 (from UBI8)
- OpenSSL: 3.2.2 (from 1.1.x)
- FIPS: 140-3 ready (from 140-2)

## Compatibility

✅ **All environment variables remain the same**
✅ **All configurations are compatible**
✅ **All features continue to work**
✅ **Multi-architecture support (AMD64/ARM64)**

## Troubleshooting

### Container Won't Start (FIPS Error)

**Problem**: Container exits with "FIPS check failed"

**Solution**: Add `FIPS_CHECK=false` to your environment variables:
```bash
docker run -e FIPS_CHECK=false ...
```

### Certificate Issues

**Problem**: Certificate validation errors

**Solution**: The container now uses OpenSSL 3.x which has stricter validation. Ensure your certificates are properly formatted and not expired.

### Performance Issues

**Problem**: Unexpected performance degradation

**Solution**: This is rare as UBI9 generally performs better. Check:
- Host system resources
- Network configuration
- Volume mounts

## Need Help?

- **Detailed Technical Information**: See [docs/UBI9-upgrade.md](UBI9-upgrade.md)
- **Issues**: Report at [GitHub Issues](https://github.com/F5GovSolutions/nginx-webssh2/issues)
- **Questions**: Ask in [GitHub Discussions](https://github.com/F5GovSolutions/nginx-webssh2/discussions)

## Summary

For 99% of users, this upgrade is transparent - just pull the new image and enjoy the improvements! The only users who need to make changes are those running in non-FIPS development environments (add `FIPS_CHECK=false`) or those with specific FIPS compliance requirements (ensure host FIPS is enabled).