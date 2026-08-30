# Lab 019: Resource Quotas and Limits

## Overview

Learn how to manage resource consumption in OpenShift using ResourceQuotas and LimitRanges. These tools help administrators control resource usage across projects and ensure fair resource distribution.

## Learning Objectives

- Create and manage ResourceQuotas
- Set compute resource quotas (CPU, memory)
- Set object count quotas
- Create LimitRanges for default container limits
- Understand quota enforcement and scopes

## Prerequisites

- Completed Lab 018: Network Policies
- OpenShift cluster running
- oc CLI authenticated with cluster-admin privileges

## Lab Instructions

### Step 1: Create a ResourceQuota

```bash
# Create a resource quota for a project
cat <<EOF | oc apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: project-quota
  namespace: default
spec:
  hard:
    requests.cpu: "4"
    requests.memory: "8Gi"
    limits.cpu: "8"
    limits.memory: "16Gi"
    persistentvolumeclaims: "5"
    pods: "20"
    services: "10"
EOF

# View the quota
oc get resourcequota project-quota

# View detailed quota usage
oc describe resourcequota project-quota
```

![Resource quota details in OpenShift web console](images/quota-details.png)

### Step 2: Test Quota Enforcement

```bash
# Try to create a pod that exceeds quota
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: quota-test
spec:
  containers:
  - name: test
    image: nginx
    resources:
      requests:
        memory: "10Gi"
        cpu: "5"
EOF

# The pod creation should be rejected
```

### Step 3: Create a LimitRange

```bash
# Create a LimitRange for default container limits
cat <<EOF | oc apply -f -
apiVersion: v1
kind: LimitRange
metadata:
  name: container-limits
  namespace: default
spec:
  limits:
  - max:
      cpu: "2"
      memory: "2Gi"
    min:
      cpu: "100m"
      memory: "256Mi"
    default:
      cpu: "500m"
      memory: "512Mi"
    defaultRequest:
      cpu: "200m"
      memory: "256Mi"
    type: Container
EOF

# View the LimitRange
oc describe limitrange container-limits
```

### Step 4: Test LimitRange Enforcement

```bash
# Create a pod without specifying resource requirements
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: limitrange-test
spec:
  containers:
  - name: test
    image: nginx
EOF

# Check the pod's resource limits (they will be set automatically)
oc get pod limitrange-test -o yaml | grep -A 5 resources
```

### Step 5: Quota with Multiple Projects

```bash
# Create quotas for different projects
for project in team-a team-b team-c; do
  oc new-project $project
  cat <<EOF | oc apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-quota
  namespace: $project
spec:
  hard:
    requests.cpu: "2"
    requests.memory: "4Gi"
    limits.cpu: "4"
    limits.memory: "8Gi"
    pods: "10"
EOF
done
```

### Step 6: Cluster Resource Quota

```bash
# Create a ClusterResourceQuota that spans multiple projects
cat <<EOF | oc apply -f -
apiVersion: quota.openshift.io/v1
kind: ClusterResourceQuota
metadata:
  name: cluster-quota
spec:
  quota:
    hard:
      pods: "50"
      services: "20"
  selector:
    annotations:
      openshift.io/requester: admin
EOF

# View cluster quotas
oc get clusterresourcequota
```

## Validation

- Quota is enforced when pods exceed limits
- LimitRange applies default values to pods without resource specs
- ClusterResourceQuota aggregates across projects

## Troubleshooting

- Check quota with `oc describe quota`
- Use `oc adm top` to view cluster resource usage
- Events show quota rejection reasons
