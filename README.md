# 🚀 OpenProject on OpenShift — Zero Privilege Deployment

[![OpenShift](https://img.shields.io/badge/OpenShift-4.x-red?logo=redhatopenshift)](https://www.redhat.com/en/technologies/cloud-computing/openshift)
[![OpenProject](https://img.shields.io/badge/OpenProject-17-blue?logo=openproject)](https://www.openproject.org)
[![SCC](https://img.shields.io/badge/SCC-restricted-brightgreen)](https://docs.openshift.com/container-platform/latest/authentication/managing-security-context-constraints.html)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-blue?logo=postgresql)](https://www.postgresql.org)
[![Ruby](https://img.shields.io/badge/Ruby-3.x-CC342D?logo=ruby&logoColor=white)](https://www.ruby-lang.org)
[![CentOS](https://img.shields.io/badge/CentOS-Stream%209-purple?logo=centos&logoColor=white)](https://www.centos.org)
[![Quay.io](https://img.shields.io/badge/Quay.io-Container-red?logo=redhat&logoColor=white)](https://quay.io)
[![Build and Push Container](https://github.com/ryannix123/openproject-on-openshift/actions/workflows/build-image.yml/badge.svg)](https://github.com/ryannix123/openproject-on-openshift/actions/workflows/build-image.yml)

> **Deploy OpenProject on OpenShift without ANY elevated privileges.** No `anyuid`. No `privileged`. Just pure, security-hardened container goodness designed for multi-tenancy.

---

## 🆓 Red Hat Developer Sandbox

The [Red Hat Developer Sandbox](https://developers.redhat.com/developer-sandbox) is a **free** OpenShift environment perfect for testing OpenProject:

- **Free tier** — No credit card required
- **Generous resources** — 14 GB RAM, 40 GB storage, 3 CPU cores
- **Latest OpenShift** — Always running a recent version (4.18+)
- **Auto-hibernation** — Deployments scale to zero after 12 hours of inactivity

### Waking Up Your Deployment

When you return after the sandbox has hibernated, your pods will be scaled down. Run this command to bring everything back up:

```bash
# Scale all deployments back to 1 replica
oc scale deployment --all --replicas=1

# Or specify your namespace explicitly
oc scale deployment --all --replicas=1 -n $(oc project -q)
```

Your data persists in the PVCs — only the pods are stopped during hibernation.

---

## ✨ Features

- ✅ CentOS Stream 9 + Ruby on Rails + Puma
- ✅ Runs as non-root (OpenShift restricted SCC compatible)
- ✅ External PostgreSQL 16 with proper health checks
- ✅ Persistent storage for assets and database
- ✅ Auto-migration on startup
- ✅ Background job processing included
- ✅ Custom entrypoint handles OpenShift's arbitrary UID assignment

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

## 📁 Files

| File | Description |
|------|-------------|
| `deploy.sh` | All-in-one deployment script (recommended) |
| `Containerfile` | Container build definition extending official image |
| `entrypoint.sh` | Arbitrary UID handling + DB migrations |

---

## ⚙️ Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DATABASE_URL` | (auto-configured) | PostgreSQL connection string |
| `OPENPROJECT_HOST__NAME` | (required) | External hostname for OpenProject |
| `OPENPROJECT_HTTPS` | `true` | Enable HTTPS (use with OpenShift routes) |
| `OPENPROJECT_HSTS` | `true` | HTTP Strict Transport Security |
| `RAILS_ENV` | `production` | Rails environment |
| `SECRET_KEY_BASE` | (auto-generated) | Rails secret key |

### Persistent Volumes

| PVC | Size | Purpose |
|-----|------|---------|
| `openproject-assets-pvc` | 50Gi | Attachments, uploads, assets |
| `postgresql-pvc` | 10Gi | Database storage |

---

## 🔧 Management Commands

```bash
# View admin credentials
cat openproject-credentials.txt

# Check OpenProject status
oc exec deployment/openproject -- bundle exec rails runner "puts OpenProject::VERSION"

# Run database migrations manually
oc exec deployment/openproject -- bundle exec rails db:migrate RAILS_ENV=production

# Access Rails console
oc exec -it deployment/openproject -- bundle exec rails console

# Check background jobs
oc exec deployment/openproject -- bundle exec rails runner "puts GoodJob::Job.count"

# Reset admin password
oc exec deployment/openproject -- bundle exec rails runner "User.admin.first.update!(password: 'newpassword', password_confirmation: 'newpassword')"

# View logs
oc logs deployment/openproject -f

# Check PostgreSQL
oc exec deployment/postgresql -- psql -U openproject -c "SELECT version();"

# Cleanup (keeps PVCs)
./deploy.sh cleanup

# Full cleanup including data
./deploy.sh cleanup
oc delete pvc openproject-assets-pvc postgresql-pvc
```

---

## 🔒 Security

This deployment runs under OpenShift's most restrictive security policy:

| Security Feature | Status |
|------------------|--------|
| Runs as non-root | ✅ |
| Random UID from namespace range | ✅ |
| All capabilities dropped | ✅ |
| No privilege escalation | ✅ |
| Seccomp profile enforced | ✅ |
| Works on Developer Sandbox | ✅ |

Verify your deployment:

```bash
# Check SCC assignment (should show "restricted" or "restricted-v2")
oc get pod -l app=openproject -o jsonpath='{.items[*].metadata.annotations.openshift\.io/scc}'

# Verify non-root UID
oc exec deployment/openproject -- id
```

---

## 🛡️ Securing Access with IP Whitelisting

OpenShift makes it easy to restrict access to your OpenProject instance by IP address using route annotations — no firewall rules or external load balancer configuration needed.

### Allow Only Specific IPs

```bash
# Allow access only from your office and home IPs
oc annotate route openproject \
  haproxy.router.openshift.io/ip_whitelist="203.0.113.50 198.51.100.0/24"
```

### Common Use Cases

| Scenario | Annotation Value |
|----------|------------------|
| Single IP | `203.0.113.50` |
| Multiple IPs | `203.0.113.50 198.51.100.25` |
| CIDR range | `10.0.0.0/8` |
| Mixed | `203.0.113.50 192.168.1.0/24 10.0.0.0/8` |

### Remove Restriction

```bash
oc annotate route openproject haproxy.router.openshift.io/ip_whitelist-
```

### Verify Configuration

```bash
oc get route openproject -o jsonpath='{.metadata.annotations.haproxy\.router\.openshift\.io/ip_whitelist}'
```

This is a great way to lock down a POC or demo instance to only your team's IPs without any infrastructure changes.

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

1. **External Database** — Use managed PostgreSQL (RDS, Azure Database, etc.)
2. **Object Storage** — Configure S3-compatible backend for attachments
3. **SMTP Configuration** — Set up email notifications (see below)
4. **Resource Limits** — Tune based on user count
5. **Backup Strategy** — Implement OADP or Velero for disaster recovery

### Resource Sizing

| Users | CPU | Memory | DB Storage | Assets Storage |
|-------|-----|--------|------------|----------------|
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

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-fix`)
3. Commit your changes (`git commit -m 'Add amazing fix'`)
4. Push to the branch (`git push origin feature/amazing-fix`)
5. Open a Pull Request

---

## 📚 References

- [OpenProject Documentation](https://www.openproject.org/docs/)
- [OpenProject Docker Guide](https://www.openproject.org/docs/installation-and-operations/installation/docker/)
- [OpenShift SCC Documentation](https://docs.openshift.com/container-platform/latest/authentication/managing-security-context-constraints.html)
- [Red Hat Developer Sandbox](https://developers.redhat.com/developer-sandbox)

---

## 🙏 Acknowledgments

- [OpenProject](https://www.openproject.org) for the amazing open source project management platform
- Red Hat for OpenShift and the Developer Sandbox
- The patterns from [nextcloud-on-openshift](https://github.com/ryannix123/nextcloud-on-openshift)

---

**⭐ If this saved you hours of debugging, consider giving it a star! ⭐**
