# Lab 011: Centralized Logging

## Overview

Application and cluster logs are critical for troubleshooting and auditing. OpenShift provides integrated logging capabilities through the OpenShift Logging operator (based on the EFK/Vector stack). This lab covers practical log management — from basic `oc logs` usage to centralized log collection and analysis.

## Learning Objectives

By completing this lab, you will:

- Use `oc logs` effectively for troubleshooting
- Understand OpenShift's logging architecture
- Install and configure the OpenShift Logging operator
- Forward and filter logs using ClusterLogForwarder
- Search and analyze logs in the Kibana/Loki console

## Prerequisites

- Completed Lab 010 (Monitoring)
- A running Deployment with active traffic
- `kubeadmin` access for operator installation

---

## Background: Logging Architecture

### Log Types in OpenShift

| Log Type | Source | Examples |
|----------|--------|----------|
| **Application** | Container stdout/stderr | App errors, request logs |
| **Infrastructure** | OpenShift system components | API server, etcd, kubelet |
| **Audit** | API server audit logs | Who did what, when |

### Logging Stack Components

- **Collector** (Fluentd or Vector): Runs on every node, collects logs
- **Store** (Elasticsearch or LokiStack): Stores and indexes logs
- **Visualization** (Kibana or OpenShift Console): Search and analyze

---

## Lab Instructions

### Step 1: Basic Log Commands

Master these essential log commands:

```bash
# View current logs of a pod
oc logs <pod-name>

# Follow logs in real-time
oc logs <pod-name> -f

# View logs from the previous container instance (after restart/crash)
oc logs <pod-name> --previous

# View logs from a specific container (multi-container pods)
oc logs <pod-name> -c <container-name>

# View logs with timestamps
oc logs <pod-name> --timestamps

# View only the last N lines
oc logs <pod-name> --tail=100

# View logs from a specific time window
oc logs <pod-name> --since=1h
oc logs <pod-name> --since-time='2024-01-01T00:00:00Z'

# View logs from all pods of a deployment
oc logs deploy/simple-web-app --all-containers

# View logs from all pods with a specific label
oc logs -l app=simple-web-app --all-containers
```

### Step 2: Debug Logging Patterns

```bash
# Shell into a pod to check log files
oc exec -it <pod-name> -- /bin/bash
ls /var/log/
cat /var/log/app.log

# Check container runtime logs on a node (requires node access)
oc debug node/<node-name>
chroot /host
journalctl -u crio

# View events related to a pod (often reveals log-related issues)
oc describe pod <pod-name> | tail -20
```

### Step 3: Install OpenShift Logging (Optional — requires cluster-admin)

> **Note**: This step requires cluster-admin privileges and sufficient cluster resources.

#### Install the Elasticsearch Operator

1. Log in as `kubeadmin`
2. **Administrator** → **Operators** → **OperatorHub**
3. Search for **OpenShift Elasticsearch Operator**
4. Click **Install** → Accept defaults → **Install**

#### Install the Cluster Logging Operator

1. **OperatorHub** → Search for **Red Hat OpenShift Logging**
2. Click **Install** → Accept defaults → **Install**

#### Create a ClusterLogging Instance

```bash
# Create the openshift-logging namespace
oc create namespace openshift-logging

# Create ClusterLogging instance
cat <<EOF | oc apply -f -
apiVersion: logging.openshift.io/v1
kind: ClusterLogging
metadata:
  name: instance
  namespace: openshift-logging
spec:
  managementState: Managed
  logStore:
    type: elasticsearch
    elasticsearch:
      nodeCount: 1
      storage:
        size: 50Gi
      resources:
        requests:
          memory: 4Gi
      redundancyPolicy: ZeroRedundancy
  visualization:
    type: kibana
    kibana:
      replicas: 1
  collection:
    logs:
      type: fluentd
EOF
```

### Step 4: Configure Log Forwarding

```bash
# Forward application logs to an external syslog server
cat <<EOF | oc apply -f -
apiVersion: logging.openshift.io/v1
kind: ClusterLogForwarder
metadata:
  name: instance
  namespace: openshift-logging
spec:
  outputs:
  - name: remote-syslog
    type: syslog
    url: 'tcp://syslog.example.com:514'
  pipelines:
  - name: app-logs
    inputRefs:
    - application
    outputRefs:
    - remote-syslog
    - default
EOF
```

### Step 5: Analyze Logs in Kibana

1. Get the Kibana URL:
```bash
oc get route kibana -n openshift-logging -o jsonpath='{.spec.host}{"\n"}'
```

2. Open Kibana in your browser
3. Create an index pattern: `app-*`
4. Explore logs using:
   - **Discover**: Search and filter logs
   - **Visualize**: Create log-based charts
   - **Dashboard**: Build monitoring dashboards

#### Useful Kibana Queries

```
# Find errors in a specific namespace
kubernetes.namespace_name:"lab-003-demo" AND level:"error"

# Find logs from a specific pod
kubernetes.pod_name:"simple-web-app-*"

# Find OOMKilled events
message:"OOM" OR message:"oom" OR message:"Out of memory"
```

---

## Validation Checklist

- [ ] Used `oc logs` with various flags (--previous, --tail, -f, --timestamps)
- [ ] Viewed logs from multi-container pods
- [ ] Explored cluster events related to logging
- [ ] Understand the logging architecture (Collector → Store → Visualization)
- [ ] (Optional) Installed and configured the Logging operator

---

## Clean Up (Optional)

```bash
# Remove ClusterLogging instance (if installed)
oc delete clusterlogging instance -n openshift-logging
```

---

## Next Lab

Proceed to [Lab 012: Scaling](../012-scaling/README.md) to learn manual and automatic scaling with HPA.
