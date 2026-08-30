# Lab 015: RBAC

## Overview

Learn how to implement Role-Based Access Control (RBAC) in OpenShift to manage user permissions and access to resources. Understand Roles, ClusterRoles, RoleBindings, ClusterRoleBindings, and Security Context Constraints (SCCs).

## Learning Objectives

- Understand RBAC concepts in OpenShift
- Create and manage Roles and ClusterRoles
- Bind roles to users and service accounts
- Use Security Context Constraints (SCCs)
- Implement least-privilege access principles

## Prerequisites

- Completed Lab 014: Persistent Storage
- OpenShift cluster running
- oc CLI authenticated with cluster-admin privileges

## Lab Instructions

### Step 1: Understand Current RBAC

```bash
# View cluster roles
oc get clusterroles

# View your current permissions
oc auth can-i --list

# Check if you can create pods
oc auth can-i create pods
```

![RBAC roles in OpenShift web console](images/rbac-roles.png)

### Step 2: Create a Role

```bash
# Create a role that allows read-only access to pods
cat <<EOF | oc apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: default
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
EOF

# View the role
oc describe role pod-reader
```

### Step 3: Create a RoleBinding

```bash
# Create a service account (simulating a user)
oc create sa pod-viewer

# Bind the role to the service account
cat <<EOF | oc apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pod-reader-binding
  namespace: default
subjects:
- kind: ServiceAccount
  name: pod-viewer
  namespace: default
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
EOF
```

### Step 4: Test RBAC

```bash
# Get the token for the service account
TOKEN=$(oc create token pod-viewer)

# Test access (should succeed for pods)
oc --token=$TOKEN get pods

# Test access (should fail for deployments)
oc --token=$TOKEN get deployments
```

### Step 5: Create a ClusterRole

```bash
# Create a cluster role that allows read-only access to all namespaces
cat <<EOF | oc apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
EOF
```

### Step 6: Security Context Constraints

```bash
# List SCCs
oc get scc

# View the restricted SCC (default for most pods)
oc describe scc restricted

# View the privileged SCC
oc describe scc privileged

# Add a service account to use the privileged SCC
oc adm policy add-scc-to-user privileged -z privileged-sa
```

## Validation

- Roles and RoleBindings are created correctly
- Users/SA have appropriate permissions
- Access is denied for unauthorized operations

## Troubleshooting

- Use `oc auth can-i --as=system:serviceaccount:namespace:sa-name` to verify
- Check RoleBinding subjects are correct
- Verify ClusterRole vs Role scoping
