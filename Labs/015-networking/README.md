# Lab 015: Networking — Service Types & Network Policies

## Overview

OpenShift networking goes beyond simple ClusterIP Services. This lab covers the different Service types (ClusterIP, NodePort, LoadBalancer), advanced Route configurations with TLS/SSL, and Network Policies for controlling traffic flow between Pods.

## Learning Objectives

By completing this lab, you will:

- Understand and create different Service types (ClusterIP, NodePort, LoadBalancer)
- Configure Routes with TLS termination modes
- Create Network Policies to control Pod-to-Pod traffic
- Implement namespace isolation using Network Policies
- Test and verify network connectivity

## Prerequisites

- Completed Lab 009 (Services & Routes basics)
- Understanding of basic networking concepts (IP, ports, protocols)

---

## Background

### Service Types

| Type | Accessibility | Use Case |
|------|--------------|----------|
| **ClusterIP** | Internal only | Default; inter-service communication |
| **NodePort** | External via node IP:port | Development/testing, non-HTTP protocols |
| **LoadBalancer** | External via cloud LB | Cloud environments, production traffic |
| **ExternalName** | DNS alias | Referencing external services |

### Route vs Service

- **Service**: L4 (TCP/UDP) load balancer, internal or node-level
- **Route**: L7 (HTTP/HTTPS) reverse proxy, hostname-based, OpenShift-specific

### Network Policies

Network Policies are Kubernetes resources that control traffic flow at the Pod level. Without Network Policies, all Pods can communicate with all other Pods (default-allow). Network Policies let you:
- Restrict which Pods can talk to each other
- Control ingress (incoming) and egress (outgoing) traffic
- Isolate namespaces from each other

---

## Lab Instructions

### Step 1: Setup

```bash
oc new-project lab-015-networking

# Deploy two applications for testing
oc new-app docker.io/nirgeier/simple-web-app:latest --name=frontend
oc new-app docker.io/nirgeier/simple-web-app:latest --name=backend

# Label the apps for Network Policy selectors
oc label deploy/frontend tier=frontend
oc label deploy/backend tier=backend

# Wait for pods to be ready
oc rollout status deploy/frontend
oc rollout status deploy/backend
```

---

### Step 2: ClusterIP Service (Default)

This is the default Service type — internal-only access.

```bash
# Verify the ClusterIP services were auto-created
oc get svc

# Test internal connectivity from frontend to backend
oc exec deploy/frontend -- curl -s http://backend.lab-015-networking.svc.cluster.local:8080

# The DNS pattern is: <service>.<namespace>.svc.cluster.local
# Within the same namespace, just <service> works:
oc exec deploy/frontend -- curl -s http://backend:8080
```

---

### Step 3: NodePort Service

NodePort exposes the service on a static port on every node.

```bash
# Create a NodePort service
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Service
metadata:
  name: frontend-nodeport
  namespace: lab-015-networking
spec:
  type: NodePort
  selector:
    app: frontend
  ports:
  - port: 8080
    targetPort: 8080
    nodePort: 30080
EOF

# Verify the NodePort service
oc get svc frontend-nodeport

# Access via node IP and NodePort
# In CRC: https://$(crc ip):30080
```

> **Note**: In OpenShift, Routes are preferred over NodePort for HTTP traffic. NodePort is useful for non-HTTP protocols (TCP/UDP).

---

### Step 4: LoadBalancer Service

In cloud environments, a LoadBalancer Service provisions an external load balancer.

```bash
# Create a LoadBalancer service
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Service
metadata:
  name: frontend-lb
  namespace: lab-015-networking
spec:
  type: LoadBalancer
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 8080
EOF

# Check the external IP (may show <pending> in CRC/on-prem)
oc get svc frontend-lb
```

> **Note**: In CRC/on-premises, LoadBalancer type may remain `<pending>`. It works with cloud providers (AWS, Azure, GCP) or with MetalLB.

---

### Step 5: Routes with TLS/SSL

#### Edge Termination (TLS ends at the router)

```bash
# Create a Route with edge TLS
oc create route edge frontend-secure \
  --service=frontend \
  --hostname=frontend.apps-crc.testing

# Verify
oc get route frontend-secure
curl -k https://frontend.apps-crc.testing
```

#### Passthrough Termination (TLS passes through to the Pod)

```bash
# Passthrough requires the app to handle TLS itself
oc create route passthrough frontend-passthrough \
  --service=frontend \
  --hostname=frontend-pt.apps-crc.testing
```

#### Re-encrypt Termination (TLS at router AND to Pod)

```bash
oc create route reencrypt frontend-reencrypt \
  --service=frontend \
  --hostname=frontend-re.apps-crc.testing \
  --dest-ca-cert=/tmp/tls.crt
```

#### TLS Termination Summary

| Mode | Router → Pod | Use Case |
|------|-------------|----------|
| **Edge** | HTTP (unencrypted) | Most common; simple setup |
| **Passthrough** | TLS (encrypted) | App manages its own certs |
| **Re-encrypt** | TLS (re-encrypted) | End-to-end encryption required |

---

### Step 6: Network Policies — Default Deny

By default, all Pods can communicate with all other Pods. Let's change that.

```bash
# Create a default-deny policy for all ingress traffic
cat <<EOF | oc apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: lab-015-networking
spec:
  podSelector: {}
  policyTypes:
  - Ingress
EOF

# Test: frontend can no longer reach backend
oc exec deploy/frontend -- curl -s --connect-timeout 5 http://backend:8080
# Should timeout or fail
```

---

### Step 7: Network Policies — Allow Specific Traffic

```bash
# Allow frontend to reach backend
cat <<EOF | oc apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: lab-015-networking
spec:
  podSelector:
    matchLabels:
      tier: backend
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: frontend
    ports:
    - protocol: TCP
      port: 8080
EOF

# Test: frontend can reach backend again
oc exec deploy/frontend -- curl -s http://backend:8080

# But other pods still cannot
oc run test-pod --image=busybox --rm -i --tty -- wget -qO- --timeout=5 http://backend:8080
# Should fail
```

---

### Step 8: Allow External Traffic via Routes

```bash
# Allow ingress from the OpenShift router (for Routes to work with default-deny)
cat <<EOF | oc apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-router
  namespace: lab-015-networking
spec:
  podSelector:
    matchLabels:
      tier: frontend
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          network.openshift.io/policy-group: ingress
EOF

# Expose and test
oc expose svc/frontend
oc get route frontend -o jsonpath='{.spec.host}{"\n"}'
```

---

### Step 9: Namespace Isolation

```bash
# Deny all traffic from other namespaces
cat <<EOF | oc apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-from-other-namespaces
  namespace: lab-015-networking
spec:
  podSelector: {}
  ingress:
  - from:
    - podSelector: {}
EOF
```

This policy allows only Pods within the same namespace to communicate.

---

## Key Concepts

### Network Policy Rules

| Rule | Effect |
|------|--------|
| No policies | All traffic allowed (default) |
| Empty `podSelector: {}` | Applies to all Pods in namespace |
| `ingress: []` (empty array) | Deny all ingress |
| `egress: []` (empty array) | Deny all egress |
| Specific `podSelector` in `from` | Allow from matching Pods |
| `namespaceSelector` in `from` | Allow from matching namespaces |

### Best Practices

1. Start with **default-deny** and add allow rules as needed
2. Use **labels** consistently for Pod and namespace selection
3. Always **allow router ingress** if you use Routes
4. Test policies with `oc exec` curl/wget commands
5. Use `oc describe networkpolicy` to verify rules

---

## Validation Checklist

- [ ] Created and tested ClusterIP, NodePort, and LoadBalancer services
- [ ] Configured Routes with Edge TLS termination
- [ ] Implemented a default-deny Network Policy
- [ ] Created allow rules for specific Pod-to-Pod traffic
- [ ] Verified network isolation works as expected

---

## Clean Up

```bash
oc delete all --all -n lab-015-networking
oc delete networkpolicy --all -n lab-015-networking
oc delete project lab-015-networking
```

---

## Next Lab

Proceed to [Lab 016: Security — SCC, RBAC & Service Accounts](../016-security/README.md) to learn about OpenShift security features.
