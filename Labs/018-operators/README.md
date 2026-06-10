# Lab 018: Operators — The Operator Pattern in OpenShift

## Overview

Operators extend Kubernetes/OpenShift with application-specific automation. An Operator encodes human operational knowledge (install, upgrade, backup, failover) into software that runs inside the cluster. OpenShift relies heavily on Operators for its own infrastructure and provides OperatorHub as a marketplace for third-party Operators.

## Learning Objectives

By completing this lab, you will:

- Understand the Operator pattern and why it matters
- Browse and install Operators from OperatorHub
- Create Custom Resources (CRs) managed by Operators
- View Operator status and managed resources
- Understand the Operator Lifecycle Manager (OLM)

## Prerequisites

- `kubeadmin` access for Operator installation
- Understanding of Kubernetes Custom Resource Definitions (CRDs)

---

## Background

### The Operator Pattern

```
Traditional Admin:
  Human → manually runs: install, configure, upgrade, backup, scale, heal

Operator:
  Human → creates Custom Resource (CR) → Operator controller watches →
  automatically performs: install, configure, upgrade, backup, scale, heal
```

### Key Concepts

| Term | Description |
|------|-------------|
| **Operator** | A controller that manages a specific application or service |
| **Custom Resource Definition (CRD)** | Extends the Kubernetes API with new resource types |
| **Custom Resource (CR)** | An instance of a CRD (e.g., a specific PostgreSQL cluster) |
| **Operator Lifecycle Manager (OLM)** | Manages Operator installation, upgrades, and dependencies |
| **OperatorHub** | A catalog of available Operators |
| **ClusterServiceVersion (CSV)** | Metadata about an Operator version |
| **Subscription** | Links an Operator to an update channel |

### Operator Capability Levels

| Level | Capabilities |
|-------|-------------|
| **Level 1 — Basic Install** | Automated install and configuration |
| **Level 2 — Seamless Upgrades** | Automated upgrades with minimal disruption |
| **Level 3 — Full Lifecycle** | Backup, restore, failure recovery |
| **Level 4 — Deep Insights** | Metrics, alerts, log processing |
| **Level 5 — Auto Pilot** | Auto-scaling, auto-tuning, anomaly detection |

---

## Lab Instructions

### Step 1: Explore OperatorHub

#### Via Web Console

1. Log in as `kubeadmin`
2. **Administrator** → **Operators** → **OperatorHub**
3. Browse categories:
   - **Database**: PostgreSQL, MongoDB, Redis
   - **Monitoring**: Prometheus, Grafana
   - **Networking**: Service Mesh, Cert Manager
   - **Security**: Vault, Keycloak
4. Use the search bar to find specific Operators
5. Click an Operator to view:
   - Description and capabilities
   - Provided APIs (CRDs)
   - Install modes

#### Via CLI

```bash
# List available package manifests (Operators)
oc get packagemanifest -n openshift-marketplace | head -20

# Search for a specific Operator
oc get packagemanifest -n openshift-marketplace | grep -i postgres

# View details of an Operator
oc describe packagemanifest postgresql -n openshift-marketplace
```

---

### Step 2: View Installed Operators

```bash
# List installed Operators (ClusterServiceVersions)
oc get csv -A

# View Subscriptions (how Operators receive updates)
oc get subscription -A

# View InstallPlans
oc get installplan -A
```

OpenShift itself uses many Operators:
```bash
# View OpenShift's built-in Operators
oc get clusteroperators
```

---

### Step 3: Install an Operator from OperatorHub

Let's install the **Web Terminal Operator** as an example (lightweight, useful).

#### Via Web Console

1. **Administrator** → **Operators** → **OperatorHub**
2. Search for **Web Terminal**
3. Click **Web Terminal** → **Install**
4. Accept defaults:
   - Update channel: `fast`
   - Installation mode: All namespaces
   - Approval strategy: Automatic
5. Click **Install**
6. Wait for status to show **Succeeded**

#### Via CLI

```bash
# Create a Subscription to install an Operator
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: web-terminal
  namespace: openshift-operators
spec:
  channel: fast
  name: web-terminal
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  installPlanApproval: Automatic
EOF

# Watch installation progress
oc get csv -n openshift-operators -w
```

---

### Step 4: Use an Operator (Create a Custom Resource)

Once installed, an Operator provides new resource types (CRDs).

```bash
# List CRDs added by the Web Terminal Operator
oc get crd | grep devworkspace

# Create a Custom Resource (the Operator will act on it)
# Example: The Web Terminal creates a DevWorkspace when you click the terminal icon
```

#### Generic Pattern for Any Operator

```bash
# 1. Find the CRDs provided by the Operator
oc get csv <operator-csv-name> -o jsonpath='{.spec.customresourcedefinitions.owned[*].name}'

# 2. View the CRD schema
oc explain <crd-name>.spec

# 3. Create a Custom Resource
cat <<EOF | oc apply -f -
apiVersion: <api-group>/<version>
kind: <CRD-Kind>
metadata:
  name: my-instance
  namespace: my-project
spec:
  # ... Operator-specific configuration
EOF

# 4. Check the resource status
oc get <crd-kind> my-instance -o yaml
```

---

### Step 5: View Operator Management

```bash
# Check Operator health
oc get csv -n openshift-operators

# View Operator logs
oc logs deploy/<operator-name> -n openshift-operators

# View events related to Operators
oc get events -n openshift-operators --sort-by='.lastTimestamp'
```

#### Via Web Console

1. **Administrator** → **Operators** → **Installed Operators**
2. Click on an Operator to see:
   - **Overview**: Status and conditions
   - **Subscription**: Update channel and approval
   - **All Instances**: Custom Resources managed by this Operator

---

### Step 6: Update and Manage Operators

```bash
# View current update channel
oc get subscription web-terminal -n openshift-operators -o jsonpath='{.spec.channel}{"\n"}'

# Change update channel
oc patch subscription web-terminal -n openshift-operators \
  --type=merge -p '{"spec":{"channel":"stable"}}'

# View pending updates (InstallPlans)
oc get installplan -n openshift-operators
```

---

## Key Concepts

### When to Use Operators vs Helm

| Scenario | Recommendation |
|----------|----------------|
| Stateless app deployment | Helm Chart |
| Database with backup/restore needs | Operator |
| App with complex lifecycle (upgrades, migrations) | Operator |
| Simple configuration management | Helm Chart |
| Day-2 operations automation | Operator |

### Common OpenShift Operators

| Operator | Purpose |
|----------|---------|
| **OpenShift Logging** | Centralized logging (EFK/Vector) |
| **OpenShift Monitoring** | Prometheus/Alertmanager stack |
| **Cert Manager** | TLS certificate automation |
| **Strimzi** | Apache Kafka management |
| **Crunchy PostgreSQL** | PostgreSQL database management |
| **Redis Enterprise** | Redis cluster management |

---

## Validation Checklist

- [ ] Browsed OperatorHub and explored available Operators
- [ ] Installed an Operator from OperatorHub
- [ ] Viewed Operator status and managed CRDs
- [ ] Understand the Operator pattern and OLM lifecycle
- [ ] Know when to use Operators vs Helm Charts

---

## Clean Up

```bash
# Uninstall the Operator
oc delete subscription web-terminal -n openshift-operators
oc delete csv $(oc get csv -n openshift-operators | grep web-terminal | awk '{print $1}') -n openshift-operators
```

---

## Next Lab

Proceed to [Lab 019: OpenShift Pipelines (Tekton CI/CD)](../019-pipelines/README.md) to learn about CI/CD in OpenShift.
