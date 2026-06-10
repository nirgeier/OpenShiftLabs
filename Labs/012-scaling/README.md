# Lab 012: Scaling — Manual and Automatic (HPA)

## Overview

Scaling ensures your applications can handle varying load. OpenShift supports both manual scaling (changing replica count) and automatic scaling via the Horizontal Pod Autoscaler (HPA). This lab covers both approaches with practical exercises.

## Learning Objectives

By completing this lab, you will:

- Manually scale Deployments up and down
- Configure Horizontal Pod Autoscaler (HPA) based on CPU/memory
- Generate load and observe autoscaling behavior
- Understand scaling best practices and limits

## Prerequisites

- Completed Lab 010 (resource requests/limits must be set for HPA)
- A running Deployment with resource requests configured

---

## Background

### Manual Scaling

Changing the `replicas` field in a Deployment. Simple and immediate.

### Horizontal Pod Autoscaler (HPA)

Automatically adjusts the number of Pods based on observed metrics (CPU, memory, custom metrics). Requires:
- Resource **requests** must be set on the Deployment
- The Metrics Server must be running (included in OpenShift by default)

| Parameter | Description |
|-----------|-------------|
| `minReplicas` | Minimum number of Pods |
| `maxReplicas` | Maximum number of Pods |
| `targetCPUUtilizationPercentage` | Scale up when average CPU exceeds this |
| `targetMemoryUtilizationPercentage` | Scale up when average memory exceeds this |

---

## Lab Instructions

### Step 1: Deploy a Scalable Application

```bash
# Create a project for scaling exercises
oc new-project lab-012-scaling

# Deploy the application
oc new-app docker.io/nirgeier/simple-web-app:latest --name=scale-demo

# Set resource requests (required for HPA)
oc set resources deploy/scale-demo \
  --requests=cpu=100m,memory=128Mi \
  --limits=cpu=500m,memory=256Mi

# Expose the application
oc expose svc/scale-demo

# Verify the deployment
oc get pods
oc get route scale-demo -o jsonpath='{.spec.host}{"\n"}'
```

---

### Step 2: Manual Scaling

#### Via CLI

```bash
# Scale to 3 replicas
oc scale deploy/scale-demo --replicas=3

# Watch pods come up
oc get pods -w

# Verify all pods are running
oc get pods -o wide

# Scale back down to 1
oc scale deploy/scale-demo --replicas=1
```

#### Via Web Console

1. **Developer** → **Topology** → click `scale-demo`
2. Click the **up arrow** (▲) next to the pod count circle
3. Scale to desired number
4. Watch pods appear in the Topology view

---

### Step 3: Configure Horizontal Pod Autoscaler

#### Via CLI

```bash
# Create an HPA: scale between 1-5 pods, target 50% CPU
oc autoscale deploy/scale-demo \
  --min=1 \
  --max=5 \
  --cpu-percent=50

# Verify HPA is created
oc get hpa

# View HPA details
oc describe hpa scale-demo
```

#### Via YAML

```bash
cat <<EOF | oc apply -f -
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: scale-demo-hpa
  namespace: lab-012-scaling
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: scale-demo
  minReplicas: 1
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 70
EOF
```

---

### Step 4: Generate Load and Observe Autoscaling

```bash
# Get the route URL
ROUTE=$(oc get route scale-demo -o jsonpath='{.spec.host}')

# Generate load using a temporary pod
oc run load-generator --image=busybox --rm -i --tty -- /bin/sh -c \
  "while true; do wget -q -O- http://scale-demo.lab-012-scaling.svc.cluster.local:8080; done"

# In another terminal, watch the HPA react
oc get hpa scale-demo -w

# Watch pods scale up
oc get pods -w
```

**Expected behavior:**
1. CPU usage rises above 50% target
2. HPA increases replica count (may take 1-2 minutes)
3. Load distributes across more pods
4. CPU per pod drops below threshold

```bash
# Stop the load generator (Ctrl+C) and watch scale-down
# Scale-down is slower (default cooldown: 5 minutes)
oc get hpa scale-demo -w
```

---

### Step 5: View Scaling Events

```bash
# View events related to scaling
oc get events --sort-by='.lastTimestamp' | grep -i "scale\|replica\|hpa"

# Describe HPA for detailed scaling history
oc describe hpa scale-demo
```

#### Via Web Console

1. **Developer** → **Observe** → **Events**
2. Filter for scaling-related events
3. Check the Deployment details for replica history

---

## Key Concepts

### When to Use Manual vs. HPA

| Scenario | Recommendation |
|----------|----------------|
| Predictable load, known peaks | Manual scaling or scheduled HPA |
| Variable traffic (web apps) | HPA on CPU/memory |
| Batch processing | Manual scaling or Job parallelism |
| Cost-sensitive environments | HPA with conservative limits |

### HPA Best Practices

- Always set resource `requests` — HPA needs them to calculate utilization
- Set realistic `min` and `max` — don't let HPA scale to 100 pods accidentally
- Monitor scale-up/down behavior — tune thresholds if pods flap
- Consider `stabilizationWindowSeconds` for smoother scaling

---

## Validation Checklist

- [ ] Manually scaled a Deployment up and down
- [ ] Created an HPA with CPU target
- [ ] Generated load and observed autoscaling behavior
- [ ] Viewed scaling events and HPA status
- [ ] Understand the difference between manual and automatic scaling

---

## Clean Up

```bash
oc delete hpa scale-demo
oc delete all -l app=scale-demo
oc delete project lab-012-scaling
```

---

## Next Lab

Proceed to [Lab 013: ConfigMaps & Secrets](../013-configmaps-secrets/README.md) to learn about application configuration management.
