#!/bin/bash
set -e

##############################################################################
# OpenProject OpenShift Entrypoint
# Handles OpenShift arbitrary UID support then starts OpenProject
##############################################################################

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# OpenShift arbitrary UID support
# Add current user to /etc/passwd if running as arbitrary UID
if ! whoami &> /dev/null; then
    if [ -w /etc/passwd ]; then
        echo "app:x:$(id -u):0:OpenProject user:/app:/sbin/nologin" >> /etc/passwd
        log_info "Added arbitrary UID $(id -u) to /etc/passwd"
    fi
fi

# Set HOME for the user
export HOME=/app

# Ensure required directories exist with proper permissions
for dir in /var/openproject/assets /var/log/openproject /tmp/openproject /app/tmp /app/log; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir" 2>/dev/null || true
    fi
done

log_success "OpenShift entrypoint complete, starting OpenProject..."

# Execute the main command (OpenProject's supervisord or whatever was passed)
exec "$@"
