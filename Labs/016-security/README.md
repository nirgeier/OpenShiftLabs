# Lab 016: Security — SCC, RBAC & Service Accounts

## Overview

Security is a first-class citizen in OpenShift. Beyond standard Kubernetes RBAC (covered in Lab 002), OpenShift adds **Security Context Constraints (SCC)** — a powerful mechanism that controls what Pods can do at the OS level. This lab covers SCC, Service Accounts, and advanced RBAC patterns that are essential for production OpenShift environments.

## Learning Objectives

By completing this lab, you will:

- Understand Security Context Constraints (SCC) and their role in OpenShift
- View and assign SCCs to Service Accounts
- Create and manage Service Accounts
- Assign roles to Service Accounts for automated workflows
- Implement least-privilege security patterns

## Prerequisites

- Completed Lab 002 (RBAC basics)
- Access to both `developer` and `kubeadmin` users

---

## Background

### Security Context Constraints (SCC)

SCCs are **unique to OpenShift** and control what a Pod is allowed to do at the host/OS level. They are more restrictive than Kubernetes' Pod Security Standards.

| SCC | Permissions | Use Case |
|-----|-------------|----------|
| `restricted` | Most restrictive (default). No root, no host resources | Standard applications |
| `restricted-v2` | Updated restricted with stricter defaults | New default in OCP 4.11+ |
| `nonroot` | Must run as non-root, limited capabilities | Apps that need specific UIDs |
| `nonroot-v2` | Updated nonroot | Newer clusters |
| `anyuid` | Can run as any UID including root | Legacy apps requiring root |
| `hostaccess` | Access to host filesystem and network | Monitoring agents |
| `hostnetwork` | Use host networking | Network plugins, load balancers |
| `privileged` | Full host access, all capabilities | Infrastructure components only |

#### What SCC Controls

- Running as root (UID 0) or specific UIDs
- Linux capabilities (NET_ADMIN, SYS_PTRACE, etc.)
- SELinux context
- Host networking, ports, PID namespace
- Volume types (hostPath, configMap, secret, etc.)
- Privileged mode
- Read-only root filesystem

### Service Accounts

Service Accounts provide an identity for processes running in Pods. Every namespace has default Service Accounts:

| Account | Purpose |
|---------|---------|
| `default` | Used by Pods if none specified |
| `builder` | Used by build processes (S2I) |
| `deployer` | Used by deployment processes |

### RBAC Recap

| Component | Scope | Description |
|-----------|-------|-------------|
| Role | Namespace | Permissions in a single namespace |
| ClusterRole | Cluster | Permissions cluster-wide |
| RoleBinding | Namespace | Grants Role to user/group/SA |
| ClusterRoleBinding | Cluster | Grants ClusterRole cluster-wide |

---

## Lab Instructions

### Step 1: Setup

```bash
oc new-project lab-016-security
```

---

### Step 2: Explore SCCs

```bash
# List all SCCs (requires cluster-admin)
oc login -u kubeadmin -p <password> https://api.crc.testing:6443
oc get scc

# Describe the default restricted SCC
oc describe scc restricted-v2

# Key fields to observe:
# - Run As User Strategy
# - SELinux Context Strategy
# - Volumes (allowed volume types)
# - Allow Privileged
# - Required Drop Capabilities
```

#### Compare SCCs

```bash
# Compare restricted vs anyuid
oc describe scc restricted-v2 | grep -E "Run As|Privileged|Capabilities|Volumes"
oc describe scc anyuid | grep -E "Run As|Privileged|Capabilities|Volumes"
```

---

### Step 3: Test SCC Restrictions

```bash
# Switch to developer
oc login -u developer -p developer https://api.crc.testing:6443
oc project lab-016-security

# Deploy an app (uses restricted SCC by default)
oc new-app docker.io/nirgeier/simple-web-app:latest --name=secure-app

# Check which SCC the pod uses
oc get pod -l app=secure-app -o jsonpath='{.items[0].metadata.annotations.openshift\.io/scc}{"\n"}'
# Should show: restricted-v2

# Try to deploy an image that requires root (will fail or be restricted)
oc new-app docker.io/nginx:latest --name=nginx-test

# Check pod status — may show CrashLoopBackOff
oc get pods -l app=nginx-test
oc logs deploy/nginx-test
```

---

### Step 4: Create and Use Service Accounts

```bash
# Create a custom Service Account
oc create serviceaccount app-service-account

# List Service Accounts in the namespace
oc get serviceaccount

# Assign the Service Account to a Deployment
oc set serviceaccount deploy/secure-app app-service-account

# Verify the pod uses the new SA
oc get pod -l app=secure-app -o jsonpath='{.items[0].spec.serviceAccountName}{"\n"}'
```

---

### Step 5: Grant SCC to a Service Account

```bash
# Switch to admin to grant SCC
oc login -u kubeadmin -p <password> https://api.crc.testing:6443

# Grant anyuid SCC to the service account (allows running as root)
oc adm policy add-scc-to-user anyuid -z app-service-account -n lab-016-security

# Verify the assignment
oc get scc anyuid -o jsonpath='{.users}'

# Now redeploy nginx with this service account
oc login -u developer -p developer https://api.crc.testing:6443
oc project lab-016-security
oc set serviceaccount deploy/nginx-test app-service-account

# Verify nginx now runs successfully
oc rollout restart deploy/nginx-test
oc get pods -l app=nginx-test
```

---

### Step 6: RBAC — Grant Permissions to Service Accounts

```bash
# Create a role that allows reading ConfigMaps and Secrets
cat <<EOF | oc apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: config-reader
  namespace: lab-016-security
rules:
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list", "watch"]
EOF

# Bind the role to the Service Account
oc create rolebinding config-reader-binding \
  --role=config-reader \
  --serviceaccount=lab-016-security:app-service-account

# Test: verify the SA can read ConfigMaps
oc auth can-i get configmaps --as=system:serviceaccount:lab-016-security:app-service-account
# Should return: yes

# Test: verify the SA cannot delete pods
oc auth can-i delete pods --as=system:serviceaccount:lab-016-security:app-service-account
# Should return: no
```

---

### Step 7: View SCC Assignment for Pods

```bash
# Check which SCC each pod in the namespace uses
oc get pods -o custom-columns=\
'NAME:.metadata.name,SCC:.metadata.annotations.openshift\.io/scc,SA:.spec.serviceAccountName'
```

---

### Step 8: Create a Restricted Service Account (Least Privilege)

```bash
# Create a SA with minimal permissions
oc create serviceaccount minimal-sa

# Create a Role with only deployment view access
cat <<EOF | oc apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: deployment-viewer
  namespace: lab-016-security
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list"]
EOF

oc create rolebinding deployment-viewer-binding \
  --role=deployment-viewer \
  --serviceaccount=lab-016-security:minimal-sa

# Verify
oc auth can-i list deployments --as=system:serviceaccount:lab-016-security:minimal-sa
oc auth can-i delete deployments --as=system:serviceaccount:lab-016-security:minimal-sa
```

---

## Key Concepts

### SCC Priority

When a Pod requests multiple SCCs (via its Service Account), OpenShift selects the most restrictive one that allows the Pod to run. The priority order matters.

### Best Practices

1. **Always use the most restrictive SCC possible** — start with `restricted-v2`
2. **Never use `privileged` SCC** for application workloads
3. **Create dedicated Service Accounts** — don't use `default`
4. **Grant SCCs to Service Accounts, not users** — `oc adm policy add-scc-to-user anyuid -z <sa-name>`
5. **Use `oc auth can-i`** to verify permissions before deployment
6. **Audit SCC usage** regularly — `oc get pods -A -o custom-columns='NS:.metadata.namespace,POD:.metadata.name,SCC:.metadata.annotations.openshift\.io/scc'`

---

## Validation Checklist

- [ ] Listed and described available SCCs
- [ ] Deployed an app and verified it uses `restricted-v2` SCC
- [ ] Created a Service Account and assigned it to a Deployment
- [ ] Granted an SCC to a Service Account to resolve permission issues
- [ ] Created Roles and RoleBindings for a Service Account
- [ ] Tested permissions with `oc auth can-i`

---

## Clean Up

```bash
oc login -u kubeadmin -p <password> https://api.crc.testing:6443
oc adm policy remove-scc-from-user anyuid -z app-service-account -n lab-016-security
oc delete project lab-016-security
```

---

## Next Lab

Proceed to [Lab 017: Helm Charts in OpenShift](../017-helm/README.md) to learn about packaging and deploying applications with Helm.
