# Lab 010: Monitoring — Logs, Events, Resource Limits & Health Checks

## Overview

Production-grade OpenShift workloads need proper observability. This lab covers the key monitoring capabilities: viewing logs and events, setting resource limits and requests, and configuring health checks (liveness and readiness probes). You'll also explore the built-in Prometheus/Grafana monitoring stack.

## Learning Objectives

By completing this lab, you will:

- View pod logs and cluster events for troubleshooting
- Set CPU and memory requests and limits on Deployments
- Configure liveness and readiness probes
- Navigate OpenShift's built-in monitoring dashboards (Prometheus & Grafana)
- Create basic alert rules

## Prerequisites

- Completed Lab 008 (Deployments)
- A running Deployment (e.g., `simple-web-app`)
- Access to both `developer` and `kubeadmin` users

---

## Background

### Logs & Events

Every container writes to stdout/stderr, which OpenShift captures as **logs**. **Events** are cluster-level records of what happened to resources (scheduling, pulling images, probe failures, OOM kills). Together, they are your first line of defense when something goes wrong.

### Resource Requests & Limits

- **Requests**: The minimum CPU/memory the scheduler guarantees for a Pod. Used for placement decisions.
- **Limits**: The maximum CPU/memory a container may use. Exceeding memory limits causes OOMKill; exceeding CPU limits causes throttling.

| Setting | Purpose | What happens if exceeded |
|---------|---------|--------------------------|
| `requests.cpu` | Scheduling guarantee | N/A (it's a minimum) |
| `requests.memory` | Scheduling guarantee | N/A (it's a minimum) |
| `limits.cpu` | Maximum CPU | Container is throttled |
| `limits.memory` | Maximum memory | Container is OOMKilled |

### Health Probes

- **Readiness probe**: Determines if a Pod can receive traffic. Failing removes it from Service endpoints.
- **Liveness probe**: Detects if a Pod is alive. Failing restarts the container.
- **Startup probe**: Used for slow-starting containers. Until it succeeds, liveness/readiness probes are disabled.

---

## Lab Instructions

### Step 1: View Pod Logs

#### Via CLI

```bash
# View current logs
oc logs deploy/simple-web-app

# Follow logs in real-time (Ctrl+C to stop)
oc logs deploy/simple-web-app -f

# View logs from a specific pod
oc get pods
oc logs <pod-name>

# View previous container logs (after a crash/restart)
oc logs <pod-name> --previous

# View logs from a specific container in a multi-container pod
oc logs <pod-name> -c <container-name>

# View logs with timestamps
oc logs <pod-name> --timestamps

# View last 50 lines
oc logs <pod-name> --tail=50
```

#### Via Web Console

1. Navigate to **Developer** → **Topology**
2. Click your deployment
3. Click the pod name under **Resources**
4. Select the **Logs** tab
5. Use the **Download** button to save logs locally

---

### Step 2: View Cluster Events

Events reveal what the cluster is doing behind the scenes.

#### Via CLI

```bash
# View events in current namespace
oc get events

# Sort events by time
oc get events --sort-by='.lastTimestamp'

# Watch events in real-time
oc get events -w

# View events for a specific pod
oc describe pod <pod-name>
# The Events section at the bottom shows pod-specific events
```

#### Via Web Console

1. **Developer** → **Observe** → **Events**
2. Filter by resource type, event type (Normal/Warning)

**Common events to watch for:**
- `Scheduled` — Pod assigned to a node
- `Pulling` / `Pulled` — Image pull activity
- `Created` / `Started` — Container lifecycle
- `Unhealthy` — Probe failures
- `FailedScheduling` — No suitable node found
- `OOMKilling` — Memory limit exceeded

---

### Step 3: Set Resource Requests and Limits

#### Via CLI

```bash
# Set resources on an existing deployment
oc set resources deploy/simple-web-app \
  --requests=cpu=100m,memory=128Mi \
  --limits=cpu=500m,memory=256Mi

# Verify the settings
oc get deploy/simple-web-app -o jsonpath='{.spec.template.spec.containers[0].resources}'
```

#### Via Web Console

1. **Developer** → **Topology** → click deployment
2. **Actions** → **Edit Deployment**
3. Scroll to **Container** section
4. Set **CPU Request**: 100m, **CPU Limit**: 500m
5. Set **Memory Request**: 128Mi, **Memory Limit**: 256Mi
6. Click **Save**

#### Understanding CPU Units

| Value | Meaning |
|-------|---------|
| `1` | 1 full CPU core |
| `500m` | 0.5 CPU core (500 millicores) |
| `100m` | 0.1 CPU core |

#### Understanding Memory Units

| Value | Meaning |
|-------|---------|
| `128Mi` | 128 mebibytes |
| `256Mi` | 256 mebibytes |
| `1Gi` | 1 gibibyte |

---

### Step 4: Configure Health Probes

#### Via CLI

```bash
# Set a readiness probe (HTTP GET)
oc set probe deploy/simple-web-app --readiness \
  --get-url=http://:8080/ \
  --initial-delay-seconds=5 \
  --period-seconds=10

# Set a liveness probe (HTTP GET)
oc set probe deploy/simple-web-app --liveness \
  --get-url=http://:8080/ \
  --initial-delay-seconds=15 \
  --period-seconds=20

# Set a liveness probe (TCP socket)
oc set probe deploy/simple-web-app --liveness \
  --open-tcp=8080 \
  --initial-delay-seconds=15

# Set a liveness probe (exec command)
oc set probe deploy/simple-web-app --liveness \
  --failure-threshold=3 \
  -- cat /tmp/healthy

# Remove a probe
oc set probe deploy/simple-web-app --remove --readiness
```

#### Via Web Console

1. **Topology** → click deployment → **Actions** → **Add Health Checks**
2. Add **Readiness Probe**:
   - Type: HTTP GET
   - Path: `/`
   - Port: `8080`
   - Initial delay: `5s`
   - Period: `10s`
3. Add **Liveness Probe**:
   - Type: HTTP GET
   - Path: `/`
   - Port: `8080`
   - Initial delay: `15s`
   - Period: `20s`
4. Click **Save**

---

### Step 5: Explore Built-in Monitoring (Prometheus)

OpenShift includes a built-in Prometheus stack for cluster monitoring.

#### Via Web Console (kubeadmin)

1. Log in as `kubeadmin`
2. Switch to **Administrator** perspective
3. Navigate to **Observe** → **Dashboards**
4. Explore pre-built dashboards:
   - **Kubernetes / Compute Resources / Namespace (Pods)**
   - **Kubernetes / Compute Resources / Pod**
5. Navigate to **Observe** → **Metrics**
6. Try PromQL queries:

```promql
# CPU usage by pod
sum(rate(container_cpu_usage_seconds_total{namespace="lab-003-demo"}[5m])) by (pod)

# Memory usage by pod
sum(container_memory_working_set_bytes{namespace="lab-003-demo"}) by (pod)

# Pod restart count
kube_pod_container_status_restarts_total{namespace="lab-003-demo"}
```

---

### Step 6: Create an Alert Rule (Optional)

```bash
# Create a PrometheusRule for high CPU usage
cat <<EOF | oc apply -f -
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: high-cpu-alert
  namespace: lab-003-demo
spec:
  groups:
  - name: app-alerts
    rules:
    - alert: HighCPUUsage
      expr: sum(rate(container_cpu_usage_seconds_total{namespace="lab-003-demo"}[5m])) by (pod) > 0.5
      for: 2m
      labels:
        severity: warning
      annotations:
        summary: "High CPU usage detected"
        description: "Pod {{ \$labels.pod }} CPU usage is above 50% for 2 minutes."
EOF
```

View alerts in **Administrator** → **Observe** → **Alerting**.

---

## Validation Checklist

- [ ] Viewed pod logs via CLI and Web Console
- [ ] Viewed cluster events and identified key event types
- [ ] Set resource requests and limits on a Deployment
- [ ] Configured readiness and liveness probes
- [ ] Explored Prometheus dashboards and ran a PromQL query
- [ ] Understand the difference between requests/limits and their effects

---

## Clean Up (Optional)

```bash
# Remove probes
oc set probe deploy/simple-web-app --remove --readiness --liveness

# Remove resource limits
oc set resources deploy/simple-web-app --requests='' --limits=''
```

---

## Next Lab

Proceed to [Lab 011: Centralized Logging](../011-logging/README.md) to set up log aggregation and analysis.

