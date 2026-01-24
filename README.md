# OpenProject on OpenShift

Deploy [OpenProject](https://www.openproject.org/) on Red Hat OpenShift using a custom container that runs without root privileges under the restricted Security Context Constraint (SCC).

## Overview

This project provides:
- Custom OpenProject container based on CentOS Stream 9
- Ruby 3.3 with Puma application server
- Supervisord for process management (web + background workers)
- OpenShift-native PostgreSQL 16 database
- Simple deployment script (`deploy.sh`)

## Quick Start

```bash
# Clone the repository
git clone https://github.com/ryannix123/openproject-on-openshift.git
cd openproject-on-openshift

# Login to OpenShift
oc login https://api.your-cluster.example.com:6443

# Select or create your project
oc new-project openproject
# or
oc project my-existing-project

# Deploy
./deploy.sh deploy openproject.apps.your-cluster.com
```

## Usage

```bash
# Deploy OpenProject
./deploy.sh deploy <route-hostname>

# Check status
./deploy.sh status

# Remove everything (including data)
./deploy.sh cleanup
```

### Examples

```bash
# Deploy
./deploy.sh deploy openproject.apps.example.com

# View deployment status
./deploy.sh status

# Clean up everything
./deploy.sh cleanup
```

To use a different container image, edit the `OPENPROJECT_IMAGE` variable at the top of `deploy.sh`.

## Building the Container

If you want to build your own container image:

```bash
# Build
podman build -t quay.io/your-registry/openproject-openshift:17 -f Containerfile .

# Push
podman push quay.io/your-registry/openproject-openshift:17

# Edit deploy.sh to use your image
# Change: OPENPROJECT_IMAGE="quay.io/ryan_nix/openproject-openshift:17"
# To:     OPENPROJECT_IMAGE="quay.io/your-registry/openproject-openshift:17"

# Deploy
./deploy.sh deploy openproject.apps.example.com
```

**Note:** The build takes 15-30 minutes due to Ruby compilation and asset precompilation.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    OpenShift Project                        │
│                                                             │
│  ┌─────────────────────┐    ┌─────────────────────────┐   │
│  │   OpenProject Pod    │    │    PostgreSQL Pod       │   │
│  │  ┌───────────────┐  │    │  ┌───────────────────┐  │   │
│  │  │   Puma Web    │  │    │  │   PostgreSQL 16   │  │   │
│  │  │   (port 8080) │  │    │  │                   │  │   │
│  │  ├───────────────┤  │    │  └───────────────────┘  │   │
│  │  │  Background   │  │    │           │             │   │
│  │  │   Workers     │  │    │    ┌──────┴──────┐      │   │
│  │  └───────────────┘  │    │    │  PVC: 10Gi  │      │   │
│  │         │           │    │    └─────────────┘      │   │
│  │  ┌──────┴──────┐    │    │                         │   │
│  │  │ PVC: 50Gi   │    │    └─────────────────────────┘   │
│  │  │  (assets)   │    │                                   │
│  │  └─────────────┘    │                                   │
│  └─────────────────────┘                                   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                TLS Route (edge)                      │   │
│  │          openproject.apps.ocp.example.com            │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Post-Deployment

### Access OpenProject

After deployment, access your instance at:

```
https://openproject.apps.your-cluster.com
```

Default login:
- **Username:** `admin`
- **Password:** `admin` (or the value shown at deployment)

**Important:** Change the admin password immediately after first login!

### View Logs

```bash
# Application logs
oc logs -f deployment/openproject

# Database logs
oc logs -f deployment/postgresql
```

### Rails Console

```bash
oc exec -it deployment/openproject -- bundle exec rails c
```

### Configure Email

Add SMTP configuration by patching the deployment:

```bash
oc set env deployment/openproject \
  OPENPROJECT_EMAIL_DELIVERY_METHOD=smtp \
  OPENPROJECT_SMTP_ADDRESS=smtp.example.com \
  OPENPROJECT_SMTP_PORT=587 \
  OPENPROJECT_SMTP_DOMAIN=example.com \
  OPENPROJECT_SMTP_AUTHENTICATION=plain \
  OPENPROJECT_SMTP_USER_NAME=your-user \
  OPENPROJECT_SMTP_PASSWORD=your-password \
  OPENPROJECT_SMTP_ENABLE_STARTTLS_AUTO=true
```

## Environment Variables

Set `OPENPROJECT_ADMIN_PASSWORD` before deployment to customize the initial admin password:

```bash
export OPENPROJECT_ADMIN_PASSWORD=MySecurePassword123
./deploy.sh deploy openproject.apps.example.com
```

## Troubleshooting

### Pod stuck in CrashLoopBackOff

Check the logs:
```bash
oc logs deployment/openproject --previous
```

Common causes:
- Database not ready yet (wait a minute and check again)
- Insufficient memory (check resource limits)

### Database Connection Errors

Verify PostgreSQL is running:
```bash
oc get pods -l app=postgresql
```

### Slow Initial Startup

OpenProject runs database migrations on first startup. This can take 3-5 minutes. The startup probe allows up to 5 minutes before considering the pod unhealthy.

## System Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | 500m | 2 cores |
| Memory | 1Gi | 4Gi |
| Database Storage | 5Gi | 10Gi |
| Assets Storage | 10Gi | 50Gi |

## License

MIT License - See [LICENSE](LICENSE) file.

## Author

Ryan Nix <ryan.nix@gmail.com>

## Acknowledgments

- [OpenProject](https://www.openproject.org/) - Open source project management software
- Based on patterns from [nextcloud-on-openshift](https://github.com/ryannix123/nextcloud-on-openshift) and [openemr-on-openshift](https://github.com/ryannix123/openemr-on-openshift)
