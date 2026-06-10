# Lab 021: MicroShift

## Overview

**MicroShift** is a lightweight, single-node OpenShift distribution designed for edge computing, IoT devices, and resource-constrained environments. It runs the core Kubernetes/OpenShift APIs on minimal hardware while maintaining compatibility with OpenShift workloads. This lab covers MicroShift architecture, management commands, and how it compares to full OpenShift.

## Learning Objectives

By completing this lab, you will:

- Understand MicroShift architecture and use cases
- Install and configure MicroShift
- Manage resources on MicroShift
- Compare management commands between OpenShift and MicroShift
- Collect and analyze logs from MicroShift
- Understand the differences and limitations vs full OpenShift

## Prerequisites

- RHEL 9.x or Fedora system (for MicroShift installation)
- Understanding of OpenShift basics (Labs 000-009)

---

## Background

### What is MicroShift?

MicroShift is a project that optimizes OpenShift for small form-factor devices and edge computing. It packages the essential Kubernetes and OpenShift components into a single binary that can run on minimal hardware.

### MicroShift vs OpenShift Comparison

| Feature | OpenShift (Full) | MicroShift |
|---------|-----------------|------------|
| **Nodes** | Multi-node cluster | Single node |
| **CPU** | 4+ cores recommended | 2 cores minimum |
| **Memory** | 16+ GB | 2 GB minimum |
| **Storage** | 100+ GB | 10 GB minimum |
| **Install** | Installer/IPI/UPI | RPM package |
| **Web Console** | Full web console | No web console |
| **Operators** | Full OLM support | Limited (no OLM) |
| **Networking** | OVN-Kubernetes (full) | OVN-Kubernetes (simplified) |
| **Storage** | Multiple CSI drivers | LVMS (LVM Storage) |
| **Registry** | Internal registry | No internal registry |
| **CI/CD** | OpenShift Pipelines | External CI/CD |
| **Monitoring** | Built-in Prometheus stack | External monitoring |
| **Updates** | OTA (Over The Air) | RPM updates + greenboot |

### Architecture

```
Full OpenShift:                    MicroShift:
┌─────────────────────┐           ┌─────────────────────┐
│ Control Plane Nodes │           │ Single Host (RHEL)  │
│ ├── API Server      │           │ ├── microshift      │
│ ├── etcd            │           │ │   (single binary) │
│ ├── Controller Mgr  │           │ │   ├── API Server  │
│ ├── Scheduler       │           │ │   ├── etcd        │
│ └── OLM             │           │ │   ├── Controller  │
├─────────────────────┤           │ │   ├── Scheduler   │
│ Worker Nodes        │           │ │   └── Kubelet     │
│ ├── Kubelet         │           │ ├── CRI-O          │
│ ├── CRI-O          │           │ ├── OVN-Kubernetes  │
│ └── OVN-Kubernetes  │           │ └── LVMS           │
└─────────────────────┘           └─────────────────────┘
```

---

## Lab Instructions

### Step 1: Install MicroShift

> **Note**: MicroShift requires RHEL 9.x. These steps assume a RHEL 9 system.

```bash
# Enable the MicroShift repository
sudo subscription-manager repos \
  --enable rhocp-4.14-for-rhel-9-$(uname -m)-rpms \
  --enable fast-datapath-for-rhel-9-$(uname -m)-rpms

# Install MicroShift
sudo dnf install -y microshift

# Copy pull secret (required for pulling Red Hat images)
sudo cp /path/to/pull-secret /etc/crio/openshift-pull-secret
sudo chown root:root /etc/crio/openshift-pull-secret
sudo chmod 600 /etc/crio/openshift-pull-secret

# Enable and start MicroShift
sudo systemctl enable --now microshift

# Check status
sudo systemctl status microshift
```

---

### Step 2: Configure kubectl/oc Access

```bash
# MicroShift generates a kubeconfig file
mkdir -p ~/.kube
sudo cp /var/lib/microshift/resources/kubeadmin/kubeconfig ~/.kube/config
sudo chown $(whoami):$(whoami) ~/.kube/config

# Verify connectivity
oc get nodes
oc get pods -A
```

Expected output:
```
NAME            STATUS   ROLES                  AGE   VERSION
microshift-01   Ready    control-plane,master   5m    v1.27.x
```

---

### Step 3: Resource Management on MicroShift

#### View Node Resources

```bash
# Check node resource capacity and usage
oc describe node $(oc get nodes -o name | head -1)

# View resource allocation
oc adm top node
oc adm top pods -A
```

#### Set Resource Limits

Since MicroShift runs on limited hardware, resource management is critical:

```bash
# Create a namespace with resource quotas
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: edge-app
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: edge-quota
  namespace: edge-app
spec:
  hard:
    requests.cpu: "500m"
    requests.memory: "512Mi"
    limits.cpu: "1"
    limits.memory: "1Gi"
    pods: "10"
EOF

# Create a LimitRange for default resource limits
cat <<EOF | oc apply -f -
apiVersion: v1
kind: LimitRange
metadata:
  name: edge-limits
  namespace: edge-app
spec:
  limits:
  - default:
      cpu: "200m"
      memory: "128Mi"
    defaultRequest:
      cpu: "50m"
      memory: "64Mi"
    type: Container
EOF
```

---

### Step 4: Deploy an Application on MicroShift

```bash
# Deploy a lightweight application
oc project edge-app

oc create deployment edge-sensor \
  --image=docker.io/nirgeier/simple-web-app:latest

# Set resource limits (important on edge devices)
oc set resources deploy/edge-sensor \
  --requests=cpu=50m,memory=64Mi \
  --limits=cpu=200m,memory=128Mi

# Expose the application
oc expose deploy/edge-sensor --port=8080
oc expose svc/edge-sensor

# Verify
oc get pods -n edge-app
oc get route -n edge-app
```

---

### Step 5: Management Commands — OpenShift vs MicroShift

#### Commands That Work the Same

| Command | OpenShift | MicroShift | Notes |
|---------|-----------|------------|-------|
| `oc get pods` | ✅ | ✅ | Same behavior |
| `oc describe pod` | ✅ | ✅ | Same behavior |
| `oc logs <pod>` | ✅ | ✅ | Same behavior |
| `oc exec -it <pod> -- bash` | ✅ | ✅ | Same behavior |
| `oc apply -f manifest.yaml` | ✅ | ✅ | Same behavior |
| `oc create deployment` | ✅ | ✅ | Same behavior |
| `oc scale deploy` | ✅ | ✅ | Same behavior |
| `oc get events` | ✅ | ✅ | Same behavior |
| `oc get nodes` | ✅ | ✅ | MicroShift: always 1 node |

#### Commands That Differ

| Command | OpenShift | MicroShift |
|---------|-----------|------------|
| `oc new-app` | ✅ Full support | ⚠️ Limited (no S2I) |
| `oc adm` | ✅ Full cluster admin | ⚠️ Subset available |
| `oc get clusteroperators` | ✅ Shows all operators | ❌ No cluster operators |
| `oc get csv` (OLM) | ✅ Operator management | ❌ No OLM |
| `oc whoami` | ✅ OAuth provider | ⚠️ kubeadmin only |

#### MicroShift-Specific Management

```bash
# MicroShift service management (systemd)
sudo systemctl status microshift     # Check service status
sudo systemctl restart microshift    # Restart MicroShift
sudo systemctl stop microshift       # Stop MicroShift
sudo systemctl start microshift      # Start MicroShift

# View MicroShift version
microshift version

# Check MicroShift configuration
cat /etc/microshift/config.yaml

# View MicroShift-specific etcd data
sudo ls /var/lib/microshift/
```

---

### Step 6: Logging — MicroShift vs OpenShift

#### MicroShift Logging

MicroShift does not include a built-in logging stack (no EFK/Loki). Logs are managed through standard Linux tools.

```bash
# View MicroShift service logs (journald)
sudo journalctl -u microshift -f                    # Follow logs
sudo journalctl -u microshift --since "1 hour ago"  # Last hour
sudo journalctl -u microshift -p err                # Errors only
sudo journalctl -u microshift --no-pager | tail -50 # Last 50 lines

# View CRI-O (container runtime) logs
sudo journalctl -u crio -f

# View OVN-Kubernetes logs
sudo journalctl -u ovn* -f

# View application pod logs (same as OpenShift)
oc logs <pod-name>
oc logs <pod-name> --previous
oc logs <pod-name> -f

# Export logs for analysis
sudo journalctl -u microshift --since today > /tmp/microshift-logs.txt
oc logs deploy/edge-sensor > /tmp/app-logs.txt
```

#### Collecting Diagnostic Data (sos report)

```bash
# Install sos (if not present)
sudo dnf install -y sos

# Collect MicroShift diagnostics
sudo sos report -o microshift

# This generates a tarball with:
# - MicroShift service logs
# - System configuration
# - Pod status and logs
# - Network configuration
# - Storage information
```

#### OpenShift vs MicroShift Logging Comparison

| Feature | OpenShift | MicroShift |
|---------|-----------|------------|
| **Application logs** | `oc logs` | `oc logs` (same) |
| **Cluster logs** | Prometheus/Loki | `journalctl -u microshift` |
| **Log aggregation** | OpenShift Logging Operator | External (rsyslog, fluentd) |
| **Visualization** | Kibana/Console | External (Grafana, etc.) |
| **Log forwarding** | ClusterLogForwarder | rsyslog or custom agent |

#### Forwarding Logs to External System

```bash
# Example: Forward MicroShift logs to remote syslog
# Edit /etc/rsyslog.d/microshift.conf
cat <<EOF | sudo tee /etc/rsyslog.d/microshift.conf
if \$programname == 'microshift' then @@syslog.example.com:514
EOF

sudo systemctl restart rsyslog
```

---

### Step 7: Storage on MicroShift (LVMS)

MicroShift uses **LVMS (LVM Storage)** for persistent volumes:

```bash
# Check available storage
sudo lvs
sudo vgs

# Create a PVC (uses LVMS)
cat <<EOF | oc apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: edge-data
  namespace: edge-app
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: topolvm-provisioner
EOF

oc get pvc -n edge-app
```

---

### Step 8: MicroShift Configuration

```bash
# View/edit MicroShift configuration
sudo cat /etc/microshift/config.yaml

# Example configuration
cat <<EOF | sudo tee /etc/microshift/config.yaml
dns:
  baseDomain: microshift.example.com
network:
  clusterNetwork:
  - cidr: 10.42.0.0/16
  serviceNetwork:
  - 10.43.0.0/16
node:
  hostnameOverride: edge-device-01
  nodeIP: 192.168.1.100
EOF

# Restart after config changes
sudo systemctl restart microshift
```

---

### Step 9: Health Monitoring on MicroShift

```bash
# Check MicroShift health
sudo systemctl is-active microshift

# Check all system pods
oc get pods -A

# Expected system namespaces:
# - kube-system (CoreDNS, etc.)
# - openshift-dns
# - openshift-ingress
# - openshift-ovn-kubernetes
# - openshift-service-ca
# - openshift-storage (if LVMS enabled)

# Check greenboot health (auto-rollback on failure)
sudo systemctl status greenboot-healthcheck
```

---

### Step 10: Updating MicroShift

```bash
# Check current version
microshift version

# Update via RPM
sudo dnf update microshift -y

# Restart after update
sudo systemctl restart microshift

# Verify the update
microshift version
oc get nodes
```

> **Greenboot**: MicroShift integrates with greenboot for automatic rollback. If health checks fail after an update, the system automatically rolls back to the previous OS version.

---

## Key Concepts

### When to Use MicroShift vs OpenShift

| Scenario | Recommendation |
|----------|----------------|
| Edge devices (retail, manufacturing) | MicroShift |
| IoT gateways | MicroShift |
| Single-server deployments | MicroShift |
| Multi-node production clusters | OpenShift |
| Complex CI/CD pipelines | OpenShift |
| Full monitoring/logging stack | OpenShift |
| Operator-managed databases | OpenShift |

### MicroShift Limitations

1. **No web console** — CLI only
2. **No OLM** — Operators must be deployed as standard Kubernetes resources
3. **No multi-node** — single node only
4. **No S2I builds** — use pre-built images or external CI
5. **No built-in monitoring** — use external monitoring
6. **Limited RBAC** — kubeadmin only (no OAuth provider by default)

---

## Validation Checklist

- [ ] Understand MicroShift architecture and use cases
- [ ] Can manage MicroShift via systemctl and oc commands
- [ ] Know the differences between OpenShift and MicroShift commands
- [ ] Can collect logs from MicroShift (journalctl, oc logs, sos report)
- [ ] Can deploy and manage applications on MicroShift
- [ ] Understand MicroShift storage (LVMS) and networking (OVN)
- [ ] Know when to choose MicroShift vs full OpenShift

---

## Clean Up

```bash
oc delete project edge-app

# Stop MicroShift (if no longer needed)
sudo systemctl stop microshift
```

---

## Summary

MicroShift brings OpenShift compatibility to the edge. While it lacks the full feature set of OpenShift (no web console, OLM, or built-in monitoring), it provides the core Kubernetes/OpenShift API surface, enabling you to deploy the same workloads on edge devices as you do in the data center. The key management differences are around service lifecycle (`systemctl`), logging (`journalctl`), and the absence of OLM-managed Operators.
