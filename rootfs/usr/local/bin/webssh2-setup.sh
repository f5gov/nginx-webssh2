#!/bin/bash
# Setup script run as root before switching to webssh2 user

cd /usr/src/webssh2

# Source environment variables
if [[ -f /etc/webssh2-env ]]; then
    source /etc/webssh2-env
fi

# Create log directory
mkdir -p /var/log/webssh2
chown webssh2:webssh2 /var/log/webssh2

# Populate s6-envdir with WebSSH2 environment variables
# s6-envdir reads files where filename=varname, content=value
ENVDIR="/etc/s6-overlay/s6-rc.d/webssh2/env"
mkdir -p "$ENVDIR"

# Export all WEBSSH2_*, DEBUG, and NODE_* variables to s6-envdir
env | grep -E "^(WEBSSH2_|DEBUG|NODE_|PORT)" | while IFS='=' read -r name value; do
    printf '%s' "$value" > "$ENVDIR/$name"
done

chown -R webssh2:webssh2 "$ENVDIR"
