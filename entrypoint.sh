#!/bin/bash
set -e

##############################################################################
# OpenProject OpenShift Entrypoint
# Handles OpenShift arbitrary UID support, database setup, then starts OpenProject
##############################################################################

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
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
cd /app

# Ensure required directories exist with proper permissions
for dir in /var/openproject/assets /var/log/openproject /tmp/openproject /app/tmp /app/log; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir" 2>/dev/null || true
    fi
done

# Wait for database to be ready
if [ -n "$DATABASE_URL" ]; then
    log_info "Waiting for database to be ready..."
    
    # Use psql for connection check (doesn't load Rails)
    for i in {1..30}; do
        if psql "$DATABASE_URL" -c "SELECT 1" > /dev/null 2>&1; then
            log_success "Database connection established"
            break
        fi
        if [ $i -eq 30 ]; then
            log_error "Database not ready after 30 attempts"
            exit 1
        fi
        log_info "Attempt $i/30 - waiting for database..."
        sleep 2
    done

    # Run database migrations
    log_info "Running database migrations (this may take a while on first run)..."
    if bundle exec rails db:migrate RAILS_ENV=production 2>&1; then
        log_success "Database migrations complete"
    else
        log_warn "Migration may have failed - check logs"
    fi

    # Seed database if needed (first run)
    log_info "Seeding database (if needed)..."
    bundle exec rails db:seed RAILS_ENV=production 2>&1 || log_warn "Seeding skipped or already done"
fi

log_success "OpenShift entrypoint complete, starting OpenProject..."

# Execute the main command
exec "$@"
