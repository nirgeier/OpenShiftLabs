# Lab 009: Services and Routes

## Overview

Pods run your application, but their IPs are dynamic. A Service provides a stable, in-cluster endpoint that load-balances traffic to healthy Pods. A Route publishes that Service externally under a hostname so users can reach your app from the internet. In this lab, you will create a Service, expose it with a Route, and optionally enable TLS (HTTPS) to secure traffic.

## Learning Objectives

- Create ClusterIP Services
- Expose Services using Routes
- Configure TLS termination on Routes

## Prerequisites

- A running Deployment (e.g., `simple-web-app` from Lab 008)

---

## Background and Key Terms

- Service: Stable in-cluster virtual IP/DNS that load-balances to Pods by label.
- Types:
	- ClusterIP: Internal-only (default).
	- NodePort: Exposes on each node’s port (rare in OpenShift).
	- LoadBalancer: Cloud LB with external address.
- Endpoint: Pod IPs behind a Service; no Ready endpoints means no traffic reaches Pods.
- Route: Publishes a Service externally under a hostname; uses the OpenShift router.
- TLS termination:
	- Edge: TLS ends at router; upstream to Service is HTTP.
	- Passthrough: TLS passes to Pod; app terminates TLS.
	- Re-encrypt: TLS ends at router and is re-established to Pod.
- Guidance: Prefer `Route` for HTTP/S; use `passthrough` only when the app must terminate TLS itself.

## Lab Instructions

### Step 1: Create a Service

In Developer perspective:
- Open `simple-web-app` in Topology
- Actions → Add Health Checks (optional) ensure port 8080 is exposed
- If Service doesn’t exist, create one via Expose → Service (ClusterIP)

### Step 2: Expose via Route

- From Topology, click the external link icon to open the app
- If no Route exists, use Expose → Route
- Verify the public URL is reachable

### Step 3: Configure TLS (Edge Termination)

- Administrator → Networking → Routes → `simple-web-app`
- Edit → Set TLS termination to Edge
- Provide certificate/key if needed (for custom hostname)
- Save and validate HTTPS access

---

## CLI Option: Using oc

Create Services and Routes with the CLI. This sequence verifies an existing deployment, creates a `Service` for it, exposes it via a `Route`, prints the public hostname, and shows creating an edge-terminated TLS route:

```bash
oc get deploy
oc expose deploy/simple-web-app --port=8080 --name=simple-web-app
oc expose svc/simple-web-app
oc get route simple-web-app -o jsonpath='{.spec.host}{"\n"}'
oc create route edge simple-web-app-edge --service=simple-web-app --hostname=app.example.com
```

---

## Validation Checklist

- Service created and shows endpoints
- Route created and public hostname works
- TLS route configured and reachable over HTTPS

---

## Clean Up (Optional)

- Delete the Route(s)
- Delete the Service (if desired)

---


## Next Lab

Proceed to [Lab 010: Monitoring with Prometheus and Grafana](../010-monitoring/README.md) to query metrics, build dashboards, and add alerts.