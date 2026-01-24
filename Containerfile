# OpenProject Container for OpenShift
# Based on official OpenProject slim image with OpenShift compatibility
#
# Author: Ryan Nix <ryan.nix@gmail.com>
# License: MIT

FROM openproject/openproject:17-slim

LABEL maintainer="Ryan Nix <ryan.nix@gmail.com>" \
      description="OpenProject for OpenShift - runs without root" \
      version="17"

# Switch to root to make modifications
USER root

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
EXPOSE 8080

# Run as non-root user (OpenShift will override with random UID)
USER 1000

# Start via OpenShift-compatible entrypoint
ENTRYPOINT ["/openshift-entrypoint.sh"]
CMD ["./docker/prod/supervisord"]
