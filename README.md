# 🚀 OpenProject on OpenShift — Zero Privilege Deployment

[![OpenShift](https://img.shields.io/badge/OpenShift-4.x-red?logo=redhatopenshift)](https://www.redhat.com/en/technologies/cloud-computing/openshift)
[![OpenProject](https://img.shields.io/badge/OpenProject-17-blue?logo=openproject)](https://www.openproject.org)
[![SCC](https://img.shields.io/badge/SCC-restricted-brightgreen)](https://docs.openshift.com/container-platform/latest/authentication/managing-security-context-constraints.html)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-blue?logo=postgresql)](https://www.postgresql.org)

> **Deploy OpenProject on OpenShift without ANY elevated privileges.** No `anyuid`. No `privileged`. Just pure, security-hardened container goodness designed for multi-tenancy.

---

## 🎯 Why This Matters

Most OpenProject deployment guides assume Docker Compose with root access or all-in-one containers that won't run on OpenShift. **That's not enterprise-ready.**

This repository provides a **battle-tested configuration** that runs OpenProject under OpenShift's most restrictive security policy — the same constraints applied to untrusted workloads. Here's what that means:

| Security Feature | Status |
| --- | --- |
| Runs as non-root | ✅ |
| Random UID from namespace range | ✅ |
| All capabilities dropped | ✅ |
| No privilege escalation | ✅ |
| Seccomp profile enforced | ✅ |
| Works on Developer Sandbox | ✅ |

**The result?** A production-ready OpenProject that your security team will actually approve.

---

## ✨ Features

* **🔒 Security First** — Runs entirely under `restricted` or `restricted-v2` SCC
* **☁️ Cloud Native** — External PostgreSQL with proper health checks and resource limits
* **🏃 Rootless Rails** — Custom entrypoint handles OpenShift's arbitrary UID assignment
* **📦 Self-Contained** — Single script deployment with auto-configuration
* **🧪 Sandbox Ready** — Tested on Red Hat Developer Sandbox (free tier!)
* **🔄 Auto-Migration** — Database migrations run automatically on startup
* **🔧 Fully Documented** — Every fix and workaround explained

---

## 📁 Repository Structure

```
openproject-on-openshift/
├── README.md                    # You're reading it
├── deploy.sh                    # 🌟 One-click deployment script
├── Containerfile                # OpenShift-compatible container
└── entrypoint.sh                # Handles arbitrary UID + migrations
```

### Files You Need

| File | Required | Description |
| --- | --- | --- |
| `deploy.sh` | ✅ | All-in-one deployment script (recommended) |
| `Containerfile` | For builds | Extends official image with OpenShift support |
| `entrypoint.sh` | For builds | Arbitrary UID handling + DB migrations |

---

## 🚀 Quick Start

### Option 1: Developer Sandbox (Easiest)

Perfect for testing or personal use on the [free Red Hat Developer Sandbox](https://developers.redhat.com/developer-sandbox):

```bash
# Clone the repo
git clone https://github.com/ryannix123/openproject-on-openshift.git
cd openproject-on-openshift

# Login to your sandbox
oc login --token=YOUR_TOKEN --server=https://api.sandbox.openshiftapps.com:6443

# Deploy! 🎉
./deploy.sh deploy openproject.apps.your-sandbox.openshiftapps.com
```

The script auto-detects your namespace. Credentials are saved to `openproject-credentials.txt`.

### Option 2: Full OpenShift Cluster

For production or self-managed clusters:

```bash
# Create namespace
oc new-project openproject

# Deploy with your hostname
./deploy.sh deploy openproject.apps.mycluster.example.com

# Check status
./deploy.sh status
```

---

## 🔧 What's Different About This Configuration?

### The Problem

The official OpenProject Docker images assume you can:

* Run as root or a specific UID
* Use the all-in-one `supervisord` with embedded PostgreSQL
* Write to arbitrary filesystem paths

**OpenShift's restricted SCC blocks all of this** — for good reason.

### The Solution

| Challenge | Our Fix |
| --- | --- |
| All-in-one container | Separate PostgreSQL + web-only OpenProject |
| Fixed UID requirement | Custom entrypoint adds arbitrary UID to `/etc/passwd` |
| Embedded database | External PostgreSQL 16 with proper PVCs |
| No database on startup | Entrypoint waits for DB + runs migrations |
| Permission errors | Group 0 permissions for OpenShift compatibility |

Every fix is automated in the deployment script.

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     OpenShift Route                         │
│                  (TLS edge termination)                     │
└─────────────────────────┬───────────────────────────────────┘
                          │ :443 → :8080
┌─────────────────────────▼───────────────────────────────────┐
│                   OpenProject Pod                           │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Puma + Background Workers               │   │
│  │                   (port 8080)                        │   │
│  │                                                      │   │
│  │   • Web interface                                    │   │
│  │   • API endpoints                                    │   │
│  │   • Background job processing                        │   │
│  └─────────────────────────┬────────────────────────────┘   │
│                            │                                │
│  ┌─────────────────────────▼────────────────────────────┐   │
│  │           Assets PVC (50Gi RWO)                      │   │
│  │   /var/openproject/assets                            │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                          │
                          │ :5432
┌─────────────────────────▼───────────────────────────────────┐
│                   PostgreSQL Pod                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              PostgreSQL 16 (RHEL9)                   │  │
│  │         registry.redhat.io/rhel9/postgresql-16       │  │
│  └─────────────────────────┬────────────────────────────┘  │
│                            │                               │
│  ┌─────────────────────────▼────────────────────────────┐  │
│  │           Database PVC (10Gi RWO)                    │  │
│  │   /var/lib/pgsql/data                                │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## 📋 Prerequisites

* **OpenShift 4.x** cluster (or Developer Sandbox)
* **oc CLI** installed and logged in
* **Storage class** available for PVCs

---

## 🔍 Verification

After deployment, verify you're running with restricted SCC:

```bash
# Check SCC assignment (should show "restricted" or "restricted-v2")
oc get pod -l app=openproject \
    -o jsonpath='{.items[*].metadata.annotations.openshift\.io/scc}'

# Verify non-root UID
oc exec deploy/openproject -- id
# Output: uid=1000680000(app) gid=0(root) ...

# Test the application
curl -I https://$(oc get route openproject -o jsonpath='{.spec.host}')
```

---

## 🐛 Troubleshooting

### Pod stuck in `CrashLoopBackOff`

```bash
# Check logs
oc logs deploy/openproject
oc logs deploy/openproject --previous

# Check PostgreSQL
oc logs deploy/postgresql
```

### Database Connection Issues

```bash
# Verify PostgreSQL is running
oc get pods -l app=postgresql

# Test connection from OpenProject pod
oc exec deploy/openproject -- psql $DATABASE_URL -c "SELECT 1"
```

### Migrations Not Running

If migrations didn't run automatically:

```bash
# Run manually
oc exec deploy/openproject -- bundle exec rails db:migrate RAILS_ENV=production
```

### Slow Initial Startup

First startup takes 3-5 minutes due to:
- Database migrations (69 migrations on fresh install)
- Asset compilation
- Background worker initialization

The startup probe allows up to 5 minutes before marking unhealthy.

---

## 🚀 Production Recommendations

For production deployments, consider:

1. **External Database** — Use managed PostgreSQL (RDS, Azure Database, etc.)
2. **Object Storage** — Configure S3-compatible backend for attachments
3. **SMTP Configuration** — Set up email notifications
4. **Resource Limits** — Tune based on user count (see below)
5. **Backup Strategy** — Implement OADP or Velero for disaster recovery

### Resource Sizing

| Users | CPU | Memory | DB Storage | Assets Storage |
| --- | --- | --- | --- | --- |
| 1-10 | 500m | 1Gi | 5Gi | 10Gi |
| 10-50 | 1 | 2Gi | 10Gi | 25Gi |
| 50-200 | 2 | 4Gi | 20Gi | 50Gi |
| 200+ | 4+ | 8Gi+ | 50Gi+ | 100Gi+ |

---

## 📧 Configure Email

Add SMTP configuration after deployment:

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

---

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-fix`)
3. Commit your changes (`git commit -m 'Add amazing fix'`)
4. Push to the branch (`git push origin feature/amazing-fix`)
5. Open a Pull Request

---

## 🙏 Acknowledgments

* [OpenProject](https://www.openproject.org) for the amazing open source project management platform
* Red Hat for OpenShift and the Developer Sandbox
* The patterns from [nextcloud-on-openshift](https://github.com/ryannix123/nextcloud-on-openshift)

---

## 📚 References

* [OpenProject Documentation](https://www.openproject.org/docs/)
* [OpenProject Docker Guide](https://www.openproject.org/docs/installation-and-operations/installation/docker/)
* [OpenShift SCC Documentation](https://docs.openshift.com/container-platform/latest/authentication/managing-security-context-constraints.html)
* [Red Hat Developer Sandbox](https://developers.redhat.com/developer-sandbox)

---

**⭐ If this saved you hours of debugging, consider giving it a star! ⭐**
