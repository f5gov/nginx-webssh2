#!/bin/bash
# Script to update WebSSH2 submodule and sync container version

set -e

echo "Updating WebSSH2 submodule..."

# Update the submodule to latest
git submodule update --remote webssh2

# Get the new version from package.json
WEBSSH2_VERSION=$(jq -r '.version' webssh2/package.json)
echo "WebSSH2 version: $WEBSSH2_VERSION"

# Check if there are changes
if git diff --cached --quiet webssh2; then
    echo "No changes in WebSSH2 submodule"
    exit 0
fi

# Commit the submodule update
git add webssh2
git commit -m "chore: update WebSSH2 to version $WEBSSH2_VERSION

Updates the WebSSH2 submodule to version $WEBSSH2_VERSION.
This will automatically trigger a new container build with matching version tags."

echo "✅ WebSSH2 submodule updated to version $WEBSSH2_VERSION"
echo ""
echo "Next steps:"
echo "1. Push to trigger the workflow: git push"
echo "2. The GitHub Actions workflow will automatically:"
echo "   - Build the container with version $WEBSSH2_VERSION"
echo "   - Tag it appropriately based on the version"
echo "   - Push to GitHub Container Registry"