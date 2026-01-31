# OpenProject Container for OpenShift
# Based on official OpenProject slim image with OpenShift compatibility
#
# Author: Ryan Nix <ryan.nix@gmail.com>

FROM openproject/openproject:17-slim

LABEL maintainer="Ryan Nix <ryan.nix@gmail.com>" \
      description="OpenProject for OpenShift - runs without root" \
      version="17.0.2"

# Switch to root to make modifications
USER root

# Install Jemalloc for better memory management and dependencies for IFC
RUN apt-get update && apt-get install -y --no-install-recommends \
    libjemalloc2 \
    curl \
    ca-certificates \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install IfcConvert for BIM/IFC file conversion
# Download IfcOpenShell pre-built binaries from GitHub releases
RUN curl -fsSL https://github.com/IfcOpenShell/IfcOpenShell/releases/download/ifcconvert-0.8.4/ifcconvert-0.8.4-linux64.zip -o /tmp/ifcconvert.zip \
    && unzip /tmp/ifcconvert.zip -d /tmp/ifcconvert \
    && mv /tmp/ifcconvert/IfcConvert /usr/local/bin/IfcConvert \
    && chmod +x /usr/local/bin/IfcConvert \
    && rm -rf /tmp/ifcconvert.zip /tmp/ifcconvert

# Enable Jemalloc memory allocator
ENV LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2

# OpenShift-compatible permissions
# Group 0 (root) needs write access for arbitrary UID support
RUN mkdir -p /var/openproject/assets /var/log/openproject /tmp/openproject \
    && chgrp -R 0 /app /var/openproject /var/log/openproject /tmp/openproject \
    && chmod -R g=u /app /var/openproject /var/log/openproject /tmp/openproject \
    && chmod -R g+w /app/tmp /app/log /var/openproject /var/log/openproject /tmp/openproject \
    && chmod g+w /etc/passwd

# Copy custom entrypoint for OpenShift
COPY entrypoint.sh /openshift-entrypoint.sh
RUN chmod +x /openshift-entrypoint.sh \
    && chgrp 0 /openshift-entrypoint.sh \
    && chmod g=u /openshift-entrypoint.sh

# Puma listens on port 8080 (OpenShift friendly)
ENV PORT=8080
ENV OPENPROJECT_RAILS__RELATIVE__URL__ROOT=
EXPOSE 8080

# Run as non-root user (OpenShift will override with random UID)
USER 1000

# Start via OpenShift-compatible entrypoint
# Use 'web' command for external database setup (not all-in-one supervisord)
ENTRYPOINT ["/openshift-entrypoint.sh"]
CMD ["./docker/prod/web"]
