#!/bin/bash
# deploy.sh - Deploy OpenProject on OpenShift
#
# Usage:
#   ./deploy.sh deploy <route-host>  - Deploy OpenProject
#   ./deploy.sh cleanup              - Remove all resources
#   ./deploy.sh status               - Show deployment status
#
# Author: Ryan Nix <ryan.nix@gmail.com>

set -e

# ─────────────────────────────────────────────────────────────────────────────
# Configuration - Edit these as needed
# ─────────────────────────────────────────────────────────────────────────────
OPENPROJECT_IMAGE="quay.io/ryan_nix/openproject-openshift:latest"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()   { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }
info()  { echo -e "${BLUE}[i]${NC} $1"; }

usage() {
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  deploy <route-host>  - Deploy OpenProject"
    echo "  cleanup              - Remove all resources"
    echo "  status               - Show deployment status"
    echo ""
    echo "Examples:"
    echo "  $0 deploy openproject.apps.example.com"
    echo "  $0 cleanup"
    echo "  $0 status"
    exit 1
}

# Generate random password
gen_password() {
    openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 24
}

deploy() {
    local ROUTE_HOST="$1"
    
    [[ -z "$ROUTE_HOST" ]] && error "Route hostname required"
    
    # Check oc login
    oc whoami > /dev/null 2>&1 || error "Not logged into OpenShift. Run 'oc login' first."
    
    local PROJECT=$(oc project -q)
    info "Deploying to project: $PROJECT"
    info "Using image: $OPENPROJECT_IMAGE"
    
    # Generate credentials
    local DB_PASSWORD=$(gen_password)
    local SECRET_KEY=$(openssl rand -hex 64)
    local ADMIN_PASSWORD="${OPENPROJECT_ADMIN_PASSWORD:-admin}"
    
    # ─────────────────────────────────────────────────────────────────────────
    # PostgreSQL Secret
    # ─────────────────────────────────────────────────────────────────────────
    log "Creating PostgreSQL secret..."
    oc apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: postgresql-secret
  labels:
    app: openproject
    app.kubernetes.io/part-of: openproject
stringData:
  database-name: openproject
  database-user: openproject
  database-password: "${DB_PASSWORD}"
EOF

    # ─────────────────────────────────────────────────────────────────────────
    # PostgreSQL PVC
    # ─────────────────────────────────────────────────────────────────────────
    log "Creating PostgreSQL PVC..."
    oc apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgresql-pvc
  labels:
    app: openproject
    app.kubernetes.io/part-of: openproject
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
EOF

    # ─────────────────────────────────────────────────────────────────────────
    # PostgreSQL Deployment
    # ─────────────────────────────────────────────────────────────────────────
    log "Deploying PostgreSQL..."
    oc apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgresql
  labels:
    app: postgresql
    app.kubernetes.io/part-of: openproject
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgresql
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: postgresql
    spec:
      containers:
        - name: postgresql
          image: registry.redhat.io/rhel9/postgresql-16:latest
          ports:
            - containerPort: 5432
          env:
            - name: POSTGRESQL_USER
              valueFrom:
                secretKeyRef:
                  name: postgresql-secret
                  key: database-user
            - name: POSTGRESQL_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgresql-secret
                  key: database-password
            - name: POSTGRESQL_DATABASE
              valueFrom:
                secretKeyRef:
                  name: postgresql-secret
                  key: database-name
          volumeMounts:
            - name: data
              mountPath: /var/lib/pgsql/data
          resources:
            requests:
              memory: "256Mi"
              cpu: "100m"
            limits:
              memory: "1Gi"
              cpu: "500m"
          readinessProbe:
            exec:
              command:
                - /usr/libexec/check-container
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:
            exec:
              command:
                - /usr/libexec/check-container
                - --live
            initialDelaySeconds: 120
            periodSeconds: 10
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: postgresql-pvc
EOF

    # ─────────────────────────────────────────────────────────────────────────
    # PostgreSQL Service
    # ─────────────────────────────────────────────────────────────────────────
    log "Creating PostgreSQL service..."
    oc apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: postgresql
  labels:
    app: postgresql
    app.kubernetes.io/part-of: openproject
spec:
  ports:
    - port: 5432
      targetPort: 5432
  selector:
    app: postgresql
EOF

    # Wait for PostgreSQL
    info "Waiting for PostgreSQL to be ready..."
    oc rollout status deployment/postgresql --timeout=300s
    sleep 10

    # ─────────────────────────────────────────────────────────────────────────
    # OpenProject Secret
    # ─────────────────────────────────────────────────────────────────────────
    log "Creating OpenProject secret..."
    oc apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: openproject-secret
  labels:
    app: openproject
    app.kubernetes.io/part-of: openproject
stringData:
  secret-key-base: "${SECRET_KEY}"
  database-url: "postgresql://openproject:${DB_PASSWORD}@postgresql:5432/openproject"
  admin-password: "${ADMIN_PASSWORD}"
EOF

    # ─────────────────────────────────────────────────────────────────────────
    # OpenProject PVC
    # ─────────────────────────────────────────────────────────────────────────
    log "Creating OpenProject assets PVC..."
    oc apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: openproject-assets-pvc
  labels:
    app: openproject
    app.kubernetes.io/part-of: openproject
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
EOF

    # ─────────────────────────────────────────────────────────────────────────
    # OpenProject Deployment
    # ─────────────────────────────────────────────────────────────────────────
    log "Deploying OpenProject..."
    oc apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: openproject
  labels:
    app: openproject
    app.kubernetes.io/part-of: openproject
spec:
  replicas: 1
  selector:
    matchLabels:
      app: openproject
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: openproject
    spec:
      containers:
        - name: openproject
          image: ${OPENPROJECT_IMAGE}
          ports:
            - containerPort: 8080
          env:
            - name: SECRET_KEY_BASE
              valueFrom:
                secretKeyRef:
                  name: openproject-secret
                  key: secret-key-base
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: openproject-secret
                  key: database-url
            - name: OPENPROJECT_HOST__NAME
              value: "${ROUTE_HOST}"
            - name: OPENPROJECT_HTTPS
              value: "true"
            - name: OPENPROJECT_HSTS
              value: "true"
            - name: OPENPROJECT_DEFAULT__LANGUAGE
              value: "en"
            - name: RAILS_ENV
              value: "production"
            - name: RAILS_LOG_TO_STDOUT
              value: "true"
            - name: WEB_CONCURRENCY
              value: "2"
            - name: RAILS_MAX_THREADS
              value: "4"
          volumeMounts:
            - name: assets
              mountPath: /var/openproject/assets
          resources:
            requests:
              memory: "1Gi"
              cpu: "500m"
            limits:
              memory: "4Gi"
              cpu: "2"
          startupProbe:
            httpGet:
              path: /health_checks/default
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 30
          readinessProbe:
            httpGet:
              path: /health_checks/default
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 10
            timeoutSeconds: 5
          livenessProbe:
            httpGet:
              path: /health_checks/default
              port: 8080
            initialDelaySeconds: 300
            periodSeconds: 30
            timeoutSeconds: 10
      volumes:
        - name: assets
          persistentVolumeClaim:
            claimName: openproject-assets-pvc
EOF

    # ─────────────────────────────────────────────────────────────────────────
    # OpenProject Service
    # ─────────────────────────────────────────────────────────────────────────
    log "Creating OpenProject service..."
    oc apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: openproject
  labels:
    app: openproject
    app.kubernetes.io/part-of: openproject
spec:
  ports:
    - port: 8080
      targetPort: 8080
  selector:
    app: openproject
EOF

    # ─────────────────────────────────────────────────────────────────────────
    # Route
    # ─────────────────────────────────────────────────────────────────────────
    log "Creating TLS route..."
    oc apply -f - <<EOF
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: openproject
  labels:
    app: openproject
    app.kubernetes.io/part-of: openproject
spec:
  host: ${ROUTE_HOST}
  to:
    kind: Service
    name: openproject
  port:
    targetPort: 8080
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
EOF

    # Wait for OpenProject
    info "Waiting for OpenProject to start (this may take several minutes)..."
    oc rollout status deployment/openproject --timeout=600s

    # ─────────────────────────────────────────────────────────────────────────
    # Summary
    # ─────────────────────────────────────────────────────────────────────────
    echo ""
    log "========================================="
    log "Deployment complete!"
    log "========================================="
    echo ""
    echo "URL: https://${ROUTE_HOST}"
    echo ""
    echo "Admin credentials:"
    echo "  Username: admin"
    echo "  Password: ${ADMIN_PASSWORD}"
    echo ""
    echo "Database credentials:"
    echo "  Host: postgresql"
    echo "  Database: openproject"
    echo "  User: openproject"
    echo "  Password: ${DB_PASSWORD}"
    echo ""
    echo "Save these credentials - they won't be shown again!"
    echo ""
}

cleanup() {
    log "Cleaning up OpenProject deployment..."
    
    oc delete deployment openproject postgresql --ignore-not-found
    oc delete service openproject postgresql --ignore-not-found
    oc delete route openproject --ignore-not-found
    oc delete secret openproject-secret postgresql-secret --ignore-not-found
    oc delete pvc openproject-assets-pvc postgresql-pvc --ignore-not-found
    
    log "Cleanup complete!"
}

status() {
    local PROJECT=$(oc project -q)
    info "OpenProject status in project: $PROJECT"
    echo ""
    
    echo "Pods:"
    oc get pods -l app.kubernetes.io/part-of=openproject 2>/dev/null || echo "  No pods found"
    echo ""
    
    echo "Services:"
    oc get svc -l app.kubernetes.io/part-of=openproject 2>/dev/null || echo "  No services found"
    echo ""
    
    echo "Routes:"
    oc get route openproject 2>/dev/null || echo "  No route found"
    echo ""
    
    echo "PVCs:"
    oc get pvc -l app.kubernetes.io/part-of=openproject 2>/dev/null || echo "  No PVCs found"
}

# Main
case "${1:-}" in
    deploy)
        deploy "$2"
        ;;
    cleanup)
        cleanup
        ;;
    status)
        status
        ;;
    *)
        usage
        ;;
esac
