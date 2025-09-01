# Lab 008: Deployments

## Overview

OpenShift supports standard Kubernetes Deployments. This lab shows how to configure probes, perform rollouts, and scale applications.

## Learning Objectives

- Understand differences between Deployment and DeploymentConfig
- Configure readiness/liveness probes
- Perform rollouts and observe behavior
- Scale workloads up and down

## Prerequisites

- A project like `lab-003-demo`
- An accessible image (e.g., `docker.io/nirgeier/simple-web-app:latest`)

---

## Background: Deployments

- Deployment: A higher-level object that manages `ReplicaSets` to roll out changes to Pods in a controlled, declarative manner. It supports strategies like rolling updates, pausing/resuming, and rollback to previous revisions.

Key terms used in this lab:
- Replica: The desired number of identical Pods managed by a controller (e.g., `Deployment`). Scaling changes this count.
- Rollout: The process of applying changes to Pods (new image, config, or probes) via `ReplicaSets`. `oc rollout status` tracks progress.
- Probe: Health checks the platform runs against Pods.
	- Readiness probe: Determines if a Pod is ready to receive traffic. Failing readiness removes the Pod from the Service endpoints.
	- Liveness probe: Detects if a Pod is alive. Failing liveness can restart the container.
- Strategy: The method used to apply changes.
	- Rolling update: Incrementally replaces old Pods with new ones, maintaining availability.
	- Recreate: Stops old Pods before starting new ones; use when state cannot be shared.
- Resource requests/limits: CPU and memory settings that inform scheduling (requests) and enforce ceilings (limits). These affect autoscaling and stability.

---

## Lab Instructions

### Step 1: Create a Deployment

In Developer perspective:
- +Add → Container images → `docker.io/nirgeier/simple-web-app:latest`
- Name: `simple-web-app`
- Create a route

Observe rollout in Topology and open the Route URL.

### Step 2: Add Health Probes

- In Topology, open `simple-web-app` → **Actions** → **Add Health Checks**
- Add readiness probe (HTTP GET `/` on port 8080)
- Add liveness probe if desired

 Probe details:
- Readiness: Use HTTP GET on path `/` port `8080`, `Initial delay: 5s`, `Period: 10s`. If it fails, traffic stops flowing to the Pod but the container keeps running.
- Liveness: Use HTTP GET or `command` when the app provides an endpoint. If it fails, the container restarts.

Validate probe behavior in Pod details.

### Step 3: Scale the Deployment

- From Topology or the Deployment page, scale replicas from 1 → 3
- Watch new pods become Ready


---

## Validation Checklist

- Deployment created, reachable via Route
- Probes configured and passing
- Scaled to desired replica count
- Rollout completed and observed
- Clear understanding of replicas, rollouts, probes, and strategies

---

## Clean Up (Optional)

- Delete `simple-web-app` and `simple-web-app-dc`
- Remove associated Service and Route
- Optionally reset probe settings or scale back replicas to 1

---



---

## CLI Option: Using oc

Work with Deployments via CLI. This sequence creates and manages a Kubernetes `Deployment`, configures probes, scales replicas, and exposes the application via a `Route`:

```bash
oc new-app docker.io/nirgeier/simple-web-app:latest --name=simple-web-app
oc rollout status deploy/simple-web-app
oc set probes deploy/simple-web-app --readiness --get-url=http://:8080/ --initial-delay-seconds=5
oc scale deploy/simple-web-app --replicas=3
oc expose svc/simple-web-app
oc get route simple-web-app -o jsonpath='{.spec.host}{"\n"}'
```

## Next Lab

Continue to [Lab 009: Services and Routes](../009-services-routes/README.md) to expose your application externally and configure TLS.
