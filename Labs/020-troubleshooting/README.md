# Lab 020: Pod Troubleshooting

## Overview

Pods fail. Knowing how to quickly diagnose and fix Pod issues is a critical skill for any OpenShift operator. This lab covers the most common Pod failure scenarios, their causes, and systematic troubleshooting approaches.

## Learning Objectives

By completing this lab, you will:

- Recognize and diagnose common Pod status codes
- Use diagnostic tools effectively (`oc describe`, `oc logs`, `oc exec`)
- Troubleshoot scheduling, image, and runtime issues
- Fix common configuration problems (ConfigMaps, Secrets, Volumes)
- Understand resource-related failures (OOMKilled, CPU throttling)

## Prerequisites

- Completed Labs 010-016
- Understanding of Pods, Deployments, Services

---

## Part 1: Common Pod Statuses and What They Mean

### Status Reference Table

| Status | Meaning | Most Common Cause |
|--------|---------|-------------------|
| **Pending** | Pod accepted but not yet scheduled | No suitable node, insufficient resources |
| **ContainerCreating** | Pod scheduled, pulling image/mounting volumes | Large image, slow registry, volume issues |
| **Running** | All containers started | Normal operation |
| **CrashLoopBackOff** | Container keeps crashing and restarting | Application error, bad config, missing deps |
| **ImagePullBackOff** | Cannot pull container image | Wrong image name, auth issues, registry down |
| **ErrImagePull** | Initial image pull failure | Same as ImagePullBackOff (first attempt) |
| **OOMKilled** | Container exceeded memory limit | Memory leak, insufficient limit, heavy workload |
| **Error** | Container exited with error code | Application crash, bad entrypoint |
| **CreateContainerConfigError** | Cannot create container config | Missing ConfigMap/Secret, bad mount |
| **Terminating** | Pod is being deleted | Finalizers stuck, long graceful shutdown |
| **Evicted** | Node evicted the Pod | Node under disk/memory pressure |
| **Init:Error** | Init container failed | Init script bug, dependency unavailable |

---

## Part 2: Essential Diagnostic Commands

### The Troubleshooting Toolkit

```bash
# 1. Overview — what's happening with all pods?
oc get pods                                    # Quick status overview
oc get pods -o wide                            # Include node and IP info
oc get pods --show-labels                      # See labels for selector issues

# 2. Deep dive — detailed info about a specific pod
oc describe pod <pod-name>                     # Full details + events
# KEY SECTIONS:
#   - Status / Conditions → current state
#   - Containers → image, state, restart count
#   - Events → chronological cluster actions

# 3. Logs — application output
oc logs <pod-name>                             # Current container logs
oc logs <pod-name> --previous                  # Logs before the last crash
oc logs <pod-name> -c <container-name>         # Specific container in multi-container pod
oc logs <pod-name> --tail=100                  # Last 100 lines
oc logs <pod-name> --since=30m                 # Last 30 minutes
oc logs <pod-name> -f                          # Follow/stream logs

# 4. Shell access — get inside the pod
oc exec -it <pod-name> -- /bin/bash            # Interactive shell
oc exec -it <pod-name> -- /bin/sh              # If bash not available
oc exec <pod-name> -- cat /etc/config/app.conf # Run a single command

# 5. Debug — when the pod won't start
oc debug deploy/<deployment-name>              # Start a debug pod with same config
oc debug node/<node-name>                      # Debug a node
```

---

## Part 3: Troubleshooting Scenarios

### Scenario 1: Pending — Pod Won't Schedule

**Symptoms:**
```bash
oc get pods
# NAME              READY   STATUS    AGE
# my-app-xxx-xxx    0/1     Pending   5m
```

**Diagnostic steps:**
```bash
# Check events
oc describe pod <pod-name> | grep -A 10 "Events:"

# Common event messages:
# "0/1 nodes are available: 1 Insufficient cpu"
# "0/1 nodes are available: 1 Insufficient memory"
# "0/1 nodes are available: 1 node(s) had taint..."
```

**Common causes and fixes:**

#### A. Insufficient Resources
```bash
# Check node capacity and current usage
oc describe node <node-name> | grep -A 5 "Allocated resources"

# Fix: Lower resource requests
oc set resources deploy/<name> --requests=cpu=50m,memory=64Mi
```

#### B. Taints and Tolerations
```bash
# Check node taints
oc get nodes -o custom-columns='NAME:.metadata.name,TAINTS:.spec.taints[*].key'

# Fix: Add toleration to the pod
oc patch deploy/<name> -p '{"spec":{"template":{"spec":{"tolerations":[{"key":"node-role.kubernetes.io/infra","operator":"Exists","effect":"NoSchedule"}]}}}}'
```

#### C. NodeSelector / Affinity Mismatch
```bash
# Check if pod has nodeSelector
oc get deploy/<name> -o jsonpath='{.spec.template.spec.nodeSelector}'

# Check available node labels
oc get nodes --show-labels

# Fix: Update nodeSelector or add labels to nodes
oc label node <node-name> disktype=ssd
```

---

### Scenario 2: CrashLoopBackOff — Container Keeps Crashing

**Symptoms:**
```bash
oc get pods
# NAME              READY   STATUS             RESTARTS   AGE
# my-app-xxx-xxx    0/1     CrashLoopBackOff   5          3m
```

**Diagnostic steps:**
```bash
# Check logs from the current (crashing) container
oc logs <pod-name>

# Check logs from the previous crash
oc logs <pod-name> --previous

# Check pod events
oc describe pod <pod-name>

# Check exit code
oc get pod <pod-name> -o jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}'
# Exit code 1: Application error
# Exit code 137: OOMKilled (SIGKILL)
# Exit code 143: SIGTERM (graceful shutdown)
```

**Common causes and fixes:**

#### A. Wrong Command / Entrypoint
```bash
# Check what command the container is running
oc get deploy/<name> -o jsonpath='{.spec.template.spec.containers[0].command}'

# Fix: Override the command
oc patch deploy/<name> -p '{"spec":{"template":{"spec":{"containers":[{"name":"<container>","command":["/bin/sh","-c","your-correct-command"]}]}}}}'

# Debug: Start a shell instead of the app
oc debug deploy/<name>
```

#### B. Missing Environment Variables
```bash
# Check which env vars the app expects
oc logs <pod-name> --previous | grep -i "error\|missing\|undefined\|required"

# Fix: Set missing env vars
oc set env deploy/<name> DATABASE_URL=postgresql://db:5432/mydb
```

#### C. Missing ConfigMap or Secret
```bash
# Check for reference issues
oc describe pod <pod-name> | grep -i "configmap\|secret\|not found"

# Fix: Create the missing ConfigMap/Secret
oc create configmap <name> --from-literal=key=value
oc create secret generic <name> --from-literal=key=value
```

---

### Scenario 3: ImagePullBackOff / ErrImagePull — Image Issues

**Symptoms:**
```bash
oc get pods
# NAME              READY   STATUS             AGE
# my-app-xxx-xxx    0/1     ImagePullBackOff   2m
```

**Diagnostic steps:**
```bash
oc describe pod <pod-name> | grep -A 5 "Events:"
# Look for:
# "Failed to pull image..." — tells you exactly what went wrong
```

**Common causes and fixes:**

#### A. Wrong Image Name / Tag
```bash
# Check current image
oc get deploy/<name> -o jsonpath='{.spec.template.spec.containers[0].image}'

# Fix: Correct the image
oc set image deploy/<name> <container>=docker.io/correct/image:tag
```

#### B. Private Registry — Missing ImagePullSecret
```bash
# Create an ImagePullSecret
oc create secret docker-registry my-registry-secret \
  --docker-server=registry.example.com \
  --docker-username=myuser \
  --docker-password=mypass

# Link secret to service account
oc secrets link default my-registry-secret --for=pull

# Or add to deployment directly
oc patch deploy/<name> -p '{"spec":{"template":{"spec":{"imagePullSecrets":[{"name":"my-registry-secret"}]}}}}'
```

#### C. Registry Authentication Issues
```bash
# Test pulling the image manually
oc debug --image=registry.example.com/my-image:tag

# Check existing secrets
oc get secrets | grep docker
oc get secret <secret-name> -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d
```

---

### Scenario 4: OOMKilled — Out of Memory

**Symptoms:**
```bash
oc get pods
# NAME              READY   STATUS    RESTARTS   AGE
# my-app-xxx-xxx    0/1     OOMKilled 3          5m

# Or check previous termination reason
oc get pod <pod-name> -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}'
# OOMKilled
```

**Diagnostic steps:**
```bash
# Check current memory limits
oc get deploy/<name> -o jsonpath='{.spec.template.spec.containers[0].resources}'

# Check actual memory usage before kill
oc adm top pod <pod-name>

# Check events
oc describe pod <pod-name> | grep -i oom
```

**Fixes:**
```bash
# Increase memory limit
oc set resources deploy/<name> --limits=memory=512Mi

# Or if the app has a memory leak, fix the application code
# Temporary workaround: increase limit significantly
oc set resources deploy/<name> --limits=memory=1Gi
```

---

### Scenario 5: CreateContainerConfigError

**Symptoms:**
```bash
oc get pods
# NAME              READY   STATUS                       AGE
# my-app-xxx-xxx    0/1     CreateContainerConfigError   1m
```

**Diagnostic steps:**
```bash
oc describe pod <pod-name>
# Look for:
# "Error: configmap 'my-config' not found"
# "Error: secret 'my-secret' not found"
```

**Common causes:**
- Referenced ConfigMap doesn't exist
- Referenced Secret doesn't exist
- ConfigMap/Secret key name mismatch
- Volume mount references missing PVC

**Fixes:**
```bash
# Create missing ConfigMap
oc create configmap <name> --from-literal=key=value

# Create missing Secret
oc create secret generic <name> --from-literal=key=value

# Check if PVC exists
oc get pvc
```

---

### Scenario 6: Terminating — Stuck Pod

**Symptoms:**
```bash
oc get pods
# NAME              READY   STATUS        AGE
# my-app-xxx-xxx    1/1     Terminating   10m
```

**Diagnostic steps:**
```bash
# Check for finalizers
oc get pod <pod-name> -o jsonpath='{.metadata.finalizers}'

# Check if the pod has a long graceful shutdown period
oc get pod <pod-name> -o jsonpath='{.spec.terminationGracePeriodSeconds}'
```

**Fixes:**
```bash
# Force delete the pod (use cautiously)
oc delete pod <pod-name> --grace-period=0 --force

# Remove finalizers (if stuck due to finalizers)
oc patch pod <pod-name> -p '{"metadata":{"finalizers":null}}'
```

---

## Part 4: Volume and Mount Issues

```bash
# Check if volumes are properly mounted
oc describe pod <pod-name> | grep -A 10 "Volumes:"
oc describe pod <pod-name> | grep -A 10 "Mounts:"

# Check PVC status
oc get pvc
# STATUS should be "Bound" — if "Pending", the PV is not available

# Check if the volume is writable
oc exec <pod-name> -- touch /path/to/volume/test-file
```

---

## Part 5: Systematic Troubleshooting Flowchart

```
Pod not working
│
├── oc get pods → What status?
│   │
│   ├── Pending → oc describe pod → Events
│   │   ├── Insufficient resources → lower requests or add nodes
│   │   ├── Taints → add tolerations
│   │   └── NodeSelector → fix labels or selectors
│   │
│   ├── ImagePullBackOff → oc describe pod → Events
│   │   ├── Wrong image → fix image name
│   │   └── Auth issue → create/fix ImagePullSecret
│   │
│   ├── CrashLoopBackOff → oc logs --previous
│   │   ├── App error → fix application code
│   │   ├── Missing config → create ConfigMap/Secret
│   │   └── Bad command → fix entrypoint/command
│   │
│   ├── OOMKilled → oc describe pod
│   │   └── Increase memory limits
│   │
│   ├── CreateContainerConfigError → oc describe pod
│   │   └── Create missing ConfigMap/Secret/PVC
│   │
│   └── Running but not working → oc logs + oc exec
│       ├── Check application logs
│       ├── Check network (Service/Route)
│       └── Check health probes
```

---

## Validation Checklist

- [ ] Can identify Pod status meanings from `oc get pods`
- [ ] Know the diagnostic command sequence: `get pods` → `describe` → `logs` → `exec`
- [ ] Can troubleshoot Pending pods (resources, taints, selectors)
- [ ] Can troubleshoot image issues (wrong name, auth, private registry)
- [ ] Can troubleshoot CrashLoopBackOff (logs, env vars, config)
- [ ] Can troubleshoot OOMKilled (memory limits)
- [ ] Can troubleshoot CreateContainerConfigError (missing resources)
- [ ] Can handle stuck Terminating pods

---

## Quick Reference Card

```bash
# === ESSENTIAL COMMANDS ===
oc get pods                              # Overview
oc describe pod <name>                   # Details + events
oc logs <pod>                            # Current logs
oc logs <pod> --previous                 # Previous crash logs
oc logs <pod> -c <container>             # Multi-container pod
oc exec -it <pod> -- /bin/bash           # Shell into pod
oc debug deploy/<name>                   # Debug pod
oc get events --sort-by='.lastTimestamp' # Recent events
oc adm top pods                          # Resource usage
oc adm top nodes                         # Node resource usage
```

---

## Next Lab

Proceed to [Lab 021: MicroShift](../021-microshift/README.md) to learn about MicroShift and how it compares to OpenShift.
