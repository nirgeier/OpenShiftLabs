# Lab 004: Deploying Your First Application

## Overview

If you've used `docker run` or created Kubernetes Deployments, this lab will feel familiar. You'll deploy a pre-built container image to OpenShift, expose it as a service, and access it through a Route (OpenShift's version of Ingress). This introduces you to the core deployment workflow in OpenShift.

## Learning Objectives

By completing this lab, you will:

- Deploy a container image to OpenShift using the web console
- Understand how OpenShift creates Deployments, Pods, and Services
- Expose your application externally using Routes
- Access and verify your running application
- Scale your deployment up and down

## Prerequisites

- Completed Lab 003 (have a project created)
- Familiarity with Docker images and container concepts
- Understanding of Kubernetes Deployments and Services

---

## Background: From Docker and Kubernetes to OpenShift

Start with familiar ideas, then map them to OpenShift:

**Docker basics:**
- `docker run nginx` starts one container.
- `-p 8080:80` publishes a port so you can reach it.
- `docker ps`, `docker logs`, `docker exec` let you inspect and interact.

**Kubernetes basics:**
- A **Pod** runs one or more containers on a node.
- A **Deployment** keeps the desired number of Pods running and handles updates.
- A **Service** gives Pods a stable internal address and load-balances traffic.

**OpenShift adds convenience on top of Kubernetes:**
- Uses the same Deployments/Pods/Services you know.
- Adds **Routes** to expose a Service outside the cluster.
- Provides a friendly web console to deploy images without writing YAML.

Think of it like this:
- Docker "run" → OpenShift creates Deployment + Pod (+ optional Service/Route).
- Docker "publish port" → OpenShift Route provides a public URL.
- `docker ps/logs/exec` → Pod pages show status, logs, and a terminal.

---

## Lab Instructions

### Step 1: Navigate to Your Project

1. Open the OpenShift web console
2. Switch to **Developer** perspective
3. Select your project: `lab-003-demo` (or the project you created earlier)
4. Click **Topology** in the left navigation

---

### Step 2: Deploy a Container Image

We'll deploy a sample web application image (like running `docker run -p 8080:8080 nirgeier/simple-web-app:latest`).

1. Click **+Add** in the left navigation

2. Choose **Container images** tile
   - This is equivalent to deploying from a pre-built Docker image

3. Fill in the image details:
   - **Image name from external registry**: `docker.io/nirgeier/simple-web-app:latest`
   - This pulls from Docker Hub (same as `docker pull`)

4. OpenShift auto-detects image info. You'll see:
   - **Application**: Create new application "simple-web-app"
   - **Name**: `simple-web-app`
   - **Resources**: Deployment (recommended)
   - **Create a route**: ✅ Checked (exposes the app)

5. Expand **Advanced Options** (optional to see settings):
   - **Target port**: 8080 (the app listens on port 8080)
   - **Resource limits**: Can set CPU/memory 

6. Click **Create**

**What just happened:**
```
Kubernetes Resources Created:
- Deployment: simple-web-app (manages Pods)
- ReplicaSet: simple-web-app-xxxxx (ensures desired replicas)
- Pod: simple-web-app-xxxxx-xxxxx (running container)
- Service: simple-web-app (internal ClusterIP service)
- Route: simple-web-app (external access, like Ingress)
```

---

### Step 3: Watch the Deployment

You'll be redirected to the **Topology** view.

1. You'll see a circular representation of your deployment:
   - Blue ring means it's deploying (pulling image, starting container)
   - Dark blue ring means running successfully
   - Pod count shown in the center (1/1)

2. **Click on the deployment circle** to open the right side panel

3. In the panel, observe:
   - **Pods**: Shows pod status (similar to `docker ps`)
   - **Resources**: Lists Deployment, Service, Route
   - **Details**: Image name, creation time

---

### Step 4: Access Your Application

**Finding the Route URL:**

1. In the Topology view, look for a small **arrow icon** (↗) in the top-right of your deployment circle
   - This is the Route URL

2. Click the arrow icon
   - Opens your application in a new browser tab

3. You should see the Simple Web App home page rendered.

---

### Step 5: Inspect Pod Details

Let's look inside the running container (equivalent to `docker inspect`).

1. In Topology view, click your deployment
2. In the right panel, click the **Resources** tab
3. Under **Pods**, click on your pod name (e.g., `simple-web-app-xxxxx-xxxxx`)

4. You'll see the Pod details page:
   - **Overview**: Status, IP, Node
   - **Details**: Container specs, image, ports
   - **Logs**: stdout/stderr (like `docker logs`)
   - **Terminal**: Shell access (like `docker exec -it`)

6. Click the **Terminal** tab:
   - Opens a shell inside the container
   - Try: `ls`
   - Try: `cat app.py`

---

### Step 6: Clean Up (Optional)

Remove the application to keep your project clean:

1. Go back to **Topology** view
2. Right-click on the deployment circle
3. Select **Delete Deployment**
4. Confirm deletion

**What gets deleted:**
- Deployment
- All Pods (containers stopped and removed)
- Service
- Route

---

## Key Concepts

### Deployment
- Manages desired state of Pods
- Handles rolling updates and rollbacks
- Ensures specified number of replicas are running
- Same as Kubernetes Deployment (uses K8s API)

### Pod
- Smallest deployable unit (one or more containers)
- Runs on a cluster node
- Has unique IP address
- Ephemeral - can be recreated anytime

### Service
- Stable internal endpoint for Pods
- Load balances traffic across replicas
- Type: ClusterIP (internal only by default)
- DNS name: `<service>.<namespace>.svc.cluster.local`

### Route
- OpenShift's way to expose services externally
- Simpler than Kubernetes Ingress
- Provides HTTP/HTTPS access with TLS termination
- Automatically gets hostname: `<route>-<namespace>.<cluster-domain>`

### ImageStreams (Preview)
- Not used in this lab, but you'll see them later
- Track image changes and trigger automatic deployments
- More advanced than direct image references

---

## CLI Option: Using oc

You can deploy the same image and expose it via the CLI. This sequence switches to your project, creates the app from an image, exposes it via a Route, retrieves the public URL, checks status, and scales the deployment:

```bash
oc project lab-003-demo
oc new-app docker.io/nirgeier/simple-web-app:latest --name=simple-web-app
oc expose svc/simple-web-app
oc get route simple-web-app -o jsonpath='{.spec.host}{"\n"}'
oc get pods
oc logs deploy/simple-web-app
oc scale deploy/simple-web-app --replicas=2
```


## Next Steps

Continue to [Lab 005: Building from Source Code](../005-docker-pipeline/README.md) to learn how OpenShift can build container images directly from Git repositories.

