# Lab 013: ConfigMaps & Secrets

## Overview

Applications need configuration: database URLs, feature flags, API keys, certificates. Hardcoding these into container images is a bad practice — it prevents portability and risks leaking secrets. OpenShift provides **ConfigMaps** for non-sensitive data and **Secrets** for sensitive data. Both can be injected into Pods as environment variables or mounted as files.

## Learning Objectives

By completing this lab, you will:

- Create and manage ConfigMaps for application configuration
- Create and manage Secrets for sensitive data
- Inject ConfigMaps and Secrets as environment variables
- Mount ConfigMaps and Secrets as files inside Pods
- Update configurations without rebuilding images

## Prerequisites

- Completed Lab 004 (basic deployment)
- A running project

---

## Background

### ConfigMaps vs Secrets

| Feature | ConfigMap | Secret |
|---------|-----------|--------|
| **Purpose** | Non-sensitive configuration | Sensitive data (passwords, tokens, keys) |
| **Storage** | Plain text in etcd | Base64-encoded in etcd (encrypted at rest in production) |
| **Size limit** | 1 MiB | 1 MiB |
| **Injection** | Env vars or volume mounts | Env vars or volume mounts |
| **RBAC** | Standard access control | Tighter access control recommended |

### How Injection Works

```
ConfigMap/Secret → Pod Spec
                    ├── envFrom: all keys become env vars
                    ├── env[].valueFrom: specific key → specific env var
                    └── volumes[]: keys become files in a directory
```

---

## Lab Instructions

### Step 1: Create a Project

```bash
oc new-project lab-013-config
```

---

### Step 2: Create a ConfigMap

#### From Literal Values

```bash
# Create a ConfigMap with key-value pairs
oc create configmap app-config \
  --from-literal=APP_ENV=production \
  --from-literal=APP_LOG_LEVEL=info \
  --from-literal=APP_MAX_CONNECTIONS=100

# Verify the ConfigMap
oc get configmap app-config -o yaml
```

#### From a File

```bash
# Create a config file
cat <<EOF > /tmp/app.properties
database.host=db.example.com
database.port=5432
database.name=myapp
cache.ttl=300
EOF

# Create ConfigMap from file
oc create configmap app-file-config --from-file=/tmp/app.properties

# Verify
oc describe configmap app-file-config
```

#### Via Web Console

1. **Administrator** → **Workloads** → **ConfigMaps**
2. Click **Create ConfigMap**
3. Enter name: `app-ui-config`
4. Add key-value pairs
5. Click **Create**

---

### Step 3: Create a Secret

#### From Literal Values

```bash
# Create a Secret with sensitive data
oc create secret generic db-credentials \
  --from-literal=DB_USER=admin \
  --from-literal=DB_PASSWORD=s3cur3P@ss \
  --from-literal=DB_HOST=db.example.com

# View the Secret (values are base64-encoded)
oc get secret db-credentials -o yaml

# Decode a specific value
oc get secret db-credentials -o jsonpath='{.data.DB_PASSWORD}' | base64 -d
```

#### TLS Secret (for certificates)

```bash
# Create a self-signed cert (for demo purposes only)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /tmp/tls.key -out /tmp/tls.crt \
  -subj "/CN=myapp.example.com"

# Create a TLS secret
oc create secret tls myapp-tls \
  --cert=/tmp/tls.crt \
  --key=/tmp/tls.key
```

#### Via Web Console

1. **Administrator** → **Workloads** → **Secrets**
2. Click **Create** → **Key/value secret**
3. Enter name: `api-keys`
4. Add key-value pairs
5. Click **Create**

---

### Step 4: Inject ConfigMap as Environment Variables

```bash
# Deploy a test application
oc new-app docker.io/nirgeier/simple-web-app:latest --name=config-demo

# Inject ALL keys from ConfigMap as env vars
oc set env deploy/config-demo --from=configmap/app-config

# Inject a SPECIFIC key as a named env var
oc set env deploy/config-demo APP_ENVIRONMENT=production

# Verify the env vars inside the pod
oc exec deploy/config-demo -- env | grep APP_
```

Expected output:
```
APP_ENV=production
APP_LOG_LEVEL=info
APP_MAX_CONNECTIONS=100
```

---

### Step 5: Inject Secret as Environment Variables

```bash
# Inject Secret as env vars
oc set env deploy/config-demo --from=secret/db-credentials

# Verify (inside the pod)
oc exec deploy/config-demo -- env | grep DB_
```

Expected output:
```
DB_USER=admin
DB_PASSWORD=s3cur3P@ss
DB_HOST=db.example.com
```

---

### Step 6: Mount ConfigMap as a Volume

```bash
# Mount ConfigMap as files in a directory
oc set volume deploy/config-demo \
  --add \
  --type=configmap \
  --configmap-name=app-file-config \
  --mount-path=/etc/app-config \
  --name=config-volume

# Verify the mounted files
oc exec deploy/config-demo -- ls /etc/app-config/
oc exec deploy/config-demo -- cat /etc/app-config/app.properties
```

---

### Step 7: Mount Secret as a Volume

```bash
# Mount Secret as files
oc set volume deploy/config-demo \
  --add \
  --type=secret \
  --secret-name=db-credentials \
  --mount-path=/etc/secrets \
  --name=secret-volume

# Verify
oc exec deploy/config-demo -- ls /etc/secrets/
oc exec deploy/config-demo -- cat /etc/secrets/DB_USER
```

---

### Step 8: Update Configuration Without Redeploying

```bash
# Update a ConfigMap value
oc patch configmap app-config -p '{"data":{"APP_LOG_LEVEL":"debug"}}'

# For env-var-based injection, pods must be restarted to pick up changes
oc rollout restart deploy/config-demo

# For volume-mounted ConfigMaps, changes propagate automatically (within ~1 minute)
# No restart needed for volume mounts!
```

---

## Key Concepts

### Best Practices

1. **Never put secrets in ConfigMaps** — use Secrets for anything sensitive
2. **Use volume mounts for files** — when apps read config files
3. **Use env vars for simple key-values** — when apps read environment
4. **Version your ConfigMaps** — use names like `app-config-v2` for safe rollouts
5. **Set appropriate RBAC** — restrict Secret access to only pods/users that need it

### Common Patterns

| Pattern | When to Use |
|---------|-------------|
| ConfigMap → env vars | Simple configuration (DB host, log level) |
| ConfigMap → volume | Config files (nginx.conf, application.yml) |
| Secret → env vars | Database credentials, API keys |
| Secret → volume | TLS certificates, SSH keys |

---

## Validation Checklist

- [ ] Created a ConfigMap from literal values and from a file
- [ ] Created a Secret from literal values
- [ ] Injected ConfigMap as environment variables
- [ ] Injected Secret as environment variables
- [ ] Mounted ConfigMap and Secret as volumes
- [ ] Updated a ConfigMap and verified the change propagated

---

## Clean Up

```bash
oc delete all -l app=config-demo
oc delete configmap app-config app-file-config
oc delete secret db-credentials myapp-tls
oc delete project lab-013-config
```

---

## Next Lab

Proceed to [Lab 014: Persistent Storage (PV & PVC)](../014-persistent-storage/README.md) to learn about persistent data in OpenShift.
