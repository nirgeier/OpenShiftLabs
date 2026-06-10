# Lab 017: Helm Charts in OpenShift

## Overview

Helm is the package manager for Kubernetes/OpenShift. A **Helm Chart** bundles all the Kubernetes resources needed to deploy an application into a single, versioned, configurable package. OpenShift has built-in Helm support in both the web console and CLI.

## Learning Objectives

By completing this lab, you will:

- Understand Helm Charts, Repositories, and Releases
- Install Helm CLI and configure it for OpenShift
- Deploy applications using Helm Charts
- Customize deployments with Helm values
- Manage Helm releases (upgrade, rollback, uninstall)
- Use the OpenShift web console Helm integration

## Prerequisites

- Completed Lab 004 (basic deployments)
- `helm` CLI installed (v3+)

---

## Background

### Helm Terminology

| Term | Description |
|------|-------------|
| **Chart** | A package of Kubernetes/OpenShift resource templates |
| **Repository** | A collection of Charts (like Docker Hub for images) |
| **Release** | A deployed instance of a Chart |
| **Values** | Configuration parameters that customize a Chart |
| **Template** | Kubernetes manifests with Go template variables |

### Why Helm?

- **Reusability**: Package complex apps into a single Chart
- **Versioning**: Track and roll back deployments
- **Configuration**: Customize via values without editing YAML
- **Ecosystem**: Thousands of community Charts available

---

## Lab Instructions

### Step 1: Install Helm CLI

```bash
# macOS
brew install helm

# Linux
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify installation
helm version
```

---

### Step 2: Add Helm Repositories

```bash
# Add popular Helm repositories
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add stable https://charts.helm.sh/stable

# Update repository index
helm repo update

# Search for charts
helm search repo nginx
helm search repo postgresql
```

---

### Step 3: Explore a Chart

```bash
# View chart details
helm show chart bitnami/nginx

# View default values (configuration options)
helm show values bitnami/nginx

# View all chart information
helm show all bitnami/nginx
```

---

### Step 4: Deploy a Chart

```bash
# Create a project
oc new-project lab-017-helm

# Install a chart with default values
helm install my-nginx bitnami/nginx

# Check the release status
helm status my-nginx

# List all releases
helm list

# View the created Kubernetes resources
oc get all -l app.kubernetes.io/instance=my-nginx
```

---

### Step 5: Customize with Values

```bash
# Create a values file
cat <<EOF > /tmp/nginx-values.yaml
replicaCount: 2
service:
  type: ClusterIP
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 250m
    memory: 256Mi
EOF

# Install with custom values
helm install my-custom-nginx bitnami/nginx -f /tmp/nginx-values.yaml

# Or override individual values
helm install my-nginx-v2 bitnami/nginx \
  --set replicaCount=3 \
  --set service.type=ClusterIP

# Verify
oc get pods -l app.kubernetes.io/instance=my-custom-nginx
```

---

### Step 6: Upgrade a Release

```bash
# Upgrade with new values
helm upgrade my-nginx bitnami/nginx --set replicaCount=3

# View upgrade history
helm history my-nginx

# Check the new pod count
oc get pods -l app.kubernetes.io/instance=my-nginx
```

---

### Step 7: Rollback a Release

```bash
# Roll back to the previous revision
helm rollback my-nginx 1

# Verify rollback
helm status my-nginx
oc get pods -l app.kubernetes.io/instance=my-nginx
```

---

### Step 8: Helm in OpenShift Web Console

OpenShift has built-in Helm support in the web console:

1. Switch to **Developer** perspective
2. Click **+Add** → **Helm Chart**
3. Browse available Charts from configured repositories
4. Click a Chart (e.g., **Node.js**) → **Install Helm Chart**
5. Configure values in the YAML editor or form view
6. Click **Install**

#### Manage Releases in Web Console

1. **Developer** → **Helm** (left navigation)
2. View all Helm releases
3. Click a release to see:
   - Resources created
   - Release notes
   - Upgrade/Rollback options

---

### Step 9: Create a Simple Chart (Optional)

```bash
# Scaffold a new chart
helm create my-app-chart

# Explore the structure
ls my-app-chart/
# Chart.yaml      - Chart metadata
# values.yaml     - Default values
# templates/       - Kubernetes resource templates
# charts/          - Dependencies

# Edit values.yaml to customize
cat my-app-chart/values.yaml

# Test template rendering (without deploying)
helm template my-app my-app-chart/

# Install your custom chart
helm install my-app my-app-chart/
```

---

## Key Concepts

### Helm vs Raw YAML

| Feature | Raw YAML | Helm |
|---------|----------|------|
| Reusability | Copy-paste | Template + values |
| Versioning | Manual | Built-in |
| Rollback | Manual `oc apply` | `helm rollback` |
| Configuration | Edit YAML directly | `--set` or values file |
| Dependencies | Manually manage | `Chart.yaml` dependencies |

### OpenShift-Specific Considerations

- Some Helm Charts may need SCC adjustments (see Lab 016)
- OpenShift Routes vs Ingress — Charts using Ingress may need the Ingress controller or Route conversion
- Use `--set` to configure OpenShift-compatible settings

---

## Validation Checklist

- [ ] Installed Helm CLI and added repositories
- [ ] Deployed a Chart with default and custom values
- [ ] Upgraded and rolled back a release
- [ ] Explored Helm Charts in the OpenShift web console
- [ ] Understand Chart structure and values

---

## Clean Up

```bash
helm uninstall my-nginx
helm uninstall my-custom-nginx
helm uninstall my-nginx-v2
oc delete project lab-017-helm
```

---

## Next Lab

Proceed to [Lab 018: Operators](../018-operators/README.md) to learn about the Operator pattern in OpenShift.
