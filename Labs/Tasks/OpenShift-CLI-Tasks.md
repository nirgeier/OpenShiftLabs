# OpenShift CLI Tasks

- Hands-on OpenShift exercises covering the essential `oc` CLI commands and
  OpenShift-specific resources (Projects, Routes, BuildConfigs, ImageStreams).
- Each task includes a description, a real-world scenario, a hint, and a
  detailed, collapsible solution.
- Practice these tasks to go from basic project operations to builds,
  rollouts, and troubleshooting.

> **Prerequisites:** a running cluster and `oc` logged in (`oc whoami` should
> print your user). New to OpenShift? Start with
> [Lab 000: Setup & Token](../000-SetupToken/README.md).

## Table of Contents

- [01. Create and Use a Project](#01-create-and-use-a-project)
- [02. Deploy an Application from an Image](#02-deploy-an-application-from-an-image)
- [03. Expose a Service with a Route](#03-expose-a-service-with-a-route)
- [04. Scale a Deployment](#04-scale-a-deployment)
- [05. ConfigMaps and Environment Variables](#05-configmaps-and-environment-variables)
- [06. Secrets as Mounted Files](#06-secrets-as-mounted-files)
- [07. Build from Source with S2I](#07-build-from-source-with-s2i)
- [08. Work with ImageStreams](#08-work-with-imagestreams)
- [09. Rolling Updates and Rollbacks](#09-rolling-updates-and-rollbacks)
- [10. Liveness and Readiness Probes](#10-liveness-and-readiness-probes)
- [11. Resource Quotas and Limits](#11-resource-quotas-and-limits)
- [12. Grant Project Access with RBAC](#12-grant-project-access-with-rbac)
- [13. Persistent Storage with a PVC](#13-persistent-storage-with-a-pvc)
- [14. Debug a Failing Pod](#14-debug-a-failing-pod)

---

## 01. Create and Use a Project

Create a new project, make it your active context, and inspect it.

**Scenario:**

- In OpenShift, a **Project** is a Kubernetes namespace with extra metadata and
  access controls.
- You want an isolated space for your work before deploying anything.

**Hint:** `oc new-project`, `oc project`, `oc status`

??? success "Solution"

    ```bash
    # Create a new project (also switches to it)
    oc new-project demo --display-name="Task Demo" --description="Practice project"

    # Show the currently selected project
    oc project

    # High-level overview of the project
    oc status

    # List all projects you can see
    oc projects
    ```

---

## 02. Deploy an Application from an Image

Deploy a container image as a running application and verify the pods.

**Scenario:**

- You have a prebuilt image and want it running quickly without writing YAML.
- `oc new-app` creates a Deployment, a Service, and (optionally) an ImageStream.

**Hint:** `oc new-app`, `oc get pods`, `oc get svc`

??? success "Solution"

    ```bash
    # Deploy the image; --name sets the resource names
    oc new-app --image=bitnami/nginx:latest --name=web

    # Watch the rollout
    oc rollout status deployment/web

    # Verify the created resources
    oc get deployment,svc,pods -l app=web
    ```

---

## 03. Expose a Service with a Route

Publish the application to the outside world using an OpenShift **Route**.

**Scenario:**

- Kubernetes Services are cluster-internal. OpenShift **Routes** expose a
  Service at a public hostname (via the built-in HAProxy router).

**Hint:** `oc expose`, `oc get route`

??? success "Solution"

    ```bash
    # Create a route for the 'web' service
    oc expose service/web

    # Get the external URL
    oc get route web -o jsonpath='{.spec.host}{"\n"}'

    # Test it (CRC uses the *.apps-crc.testing domain)
    curl -s "http://$(oc get route web -o jsonpath='{.spec.host}')" | head

    # For HTTPS with TLS termination at the router:
    oc create route edge web-secure --service=web
    ```

---

## 04. Scale a Deployment

Scale the application up and down, then verify the replica count.

**Scenario:**

- Traffic increased and you need more replicas of a stateless app.

**Hint:** `oc scale`, `oc get pods`

??? success "Solution"

    ```bash
    # Scale up to 3 replicas
    oc scale deployment/web --replicas=3

    # Verify
    oc get pods -l app=web
    oc get deployment web

    # Scale back down
    oc scale deployment/web --replicas=1
    ```

---

## 05. ConfigMaps and Environment Variables

Create a ConfigMap and inject its values into a deployment as env vars.

**Scenario:**

- You need to configure an app (DB host, feature flags) without rebuilding the
  image.

**Hint:** `oc create configmap`, `oc set env --from`

??? success "Solution"

    ```bash
    # Create a ConfigMap from literal key/values
    oc create configmap app-config \
      --from-literal=GREETING="Hello OpenShift" \
      --from-literal=LOG_LEVEL=debug

    # Inject ALL keys as environment variables into the deployment
    oc set env deployment/web --from=configmap/app-config

    # Confirm the env vars inside a pod
    POD=$(oc get pod -l app=web -o name | head -1)
    oc exec "$POD" -- printenv GREETING LOG_LEVEL
    ```

---

## 06. Secrets as Mounted Files

Create a Secret and mount it into the pod as files.

**Scenario:**

- Your app reads credentials from a file path rather than env vars.

**Hint:** `oc create secret generic`, `oc set volume`

??? success "Solution"

    ```bash
    # Create a generic secret
    oc create secret generic app-secret \
      --from-literal=username=admin \
      --from-literal=password='S3cr3t!'

    # Mount it as a read-only volume at /etc/app-secret
    oc set volume deployment/web --add \
      --name=secret-vol \
      --secret-name=app-secret \
      --mount-path=/etc/app-secret \
      --read-only=true

    # Verify the files appear inside the pod
    POD=$(oc get pod -l app=web -o name | head -1)
    oc exec "$POD" -- ls -l /etc/app-secret
    oc exec "$POD" -- cat /etc/app-secret/username
    ```

---

## 07. Build from Source with S2I

Build a container image directly from source code using Source-to-Image (S2I).

**Scenario:**

- You have application source in Git and want OpenShift to build and deploy it
  without a Dockerfile.

**Hint:** `oc new-app <builder>~<git-url>`, `oc logs -f bc/<name>`

??? success "Solution"

    ```bash
    # Build + deploy a Node.js sample using the nodejs S2I builder
    oc new-app nodejs~https://github.com/sclorg/nodejs-ex.git --name=nodejs-ex

    # Follow the build logs
    oc logs -f bc/nodejs-ex

    # After the build completes, expose it
    oc expose service/nodejs-ex
    oc get route nodejs-ex -o jsonpath='{.spec.host}{"\n"}'

    # Trigger a new build later with:
    oc start-build nodejs-ex
    ```

---

## 08. Work with ImageStreams

Inspect an ImageStream and tag an image for a stable, stream-based deployment.

**Scenario:**

- ImageStreams give you a stable, internal reference to images and can trigger
  redeploys when the underlying image changes.

**Hint:** `oc get is`, `oc import-image`, `oc tag`

??? success "Solution"

    ```bash
    # List ImageStreams in the project
    oc get imagestream

    # Import an external image into a new ImageStream
    oc import-image myredis:7 --from=redis:7 --confirm

    # Describe the tags/history
    oc describe imagestream myredis

    # Promote a tag (e.g., mark :7 as :stable)
    oc tag myredis:7 myredis:stable
    ```

---

## 09. Rolling Updates and Rollbacks

Update the image of a deployment, watch the rollout, then roll back.

**Scenario:**

- You shipped a new version that misbehaves and must revert with no downtime.

**Hint:** `oc set image`, `oc rollout status`, `oc rollout undo`

??? success "Solution"

    ```bash
    # Update the container image (container name matches the deployment: web)
    oc set image deployment/web web=bitnami/nginx:1.25

    # Watch the rollout
    oc rollout status deployment/web

    # Inspect rollout history
    oc rollout history deployment/web

    # Roll back to the previous revision
    oc rollout undo deployment/web

    # Confirm
    oc rollout status deployment/web
    ```

---

## 10. Liveness and Readiness Probes

Add health probes so OpenShift can restart frozen pods and gate traffic.

**Scenario:**

- Your app can deadlock or take time to warm up. Liveness restarts unhealthy
  pods; readiness holds traffic until the pod is ready.

**Hint:** `oc set probe`

??? success "Solution"

    ```bash
    # Readiness probe: HTTP GET / on port 8080
    oc set probe deployment/web --readiness \
      --get-url=http://:8080/ \
      --initial-delay-seconds=5 --period-seconds=10

    # Liveness probe: same endpoint, restart on failure
    oc set probe deployment/web --liveness \
      --get-url=http://:8080/ \
      --initial-delay-seconds=15 --failure-threshold=3

    # Verify the probes are set
    oc get deployment web -o jsonpath='{.spec.template.spec.containers[0].readinessProbe}{"\n"}'
    ```

---

## 11. Resource Quotas and Limits

Constrain how much CPU/memory a project can consume.

**Scenario:**

- You share a cluster and must prevent one project from starving others.

**Hint:** `oc create quota`, `oc create limitrange` (or `oc create -f`)

??? success "Solution"

    ```bash
    # Cap total requests/limits for the whole project
    oc create quota demo-quota \
      --hard=requests.cpu=1,requests.memory=1Gi,limits.cpu=2,limits.memory=2Gi

    # Set default per-container requests/limits via a LimitRange
    cat <<'EOF' | oc apply -f -
    apiVersion: v1
    kind: LimitRange
    metadata:
      name: demo-limits
    spec:
      limits:
        - type: Container
          default:
            cpu: 250m
            memory: 256Mi
          defaultRequest:
            cpu: 100m
            memory: 128Mi
    EOF

    # Inspect usage
    oc get resourcequota demo-quota -o yaml
    oc describe limitrange demo-limits
    ```

---

## 12. Grant Project Access with RBAC

Give another user permission to work in your project.

**Scenario:**

- A teammate needs edit access to your project but not cluster-admin.

**Hint:** `oc adm policy add-role-to-user`, `oc get rolebindings`

??? success "Solution"

    ```bash
    # Grant the 'edit' role to user 'developer' in the current project
    oc adm policy add-role-to-user edit developer

    # View who has access
    oc get rolebindings -o wide

    # Remove the access when done
    oc adm policy remove-role-from-user edit developer
    ```

---

## 13. Persistent Storage with a PVC

Request persistent storage and mount it so data survives pod restarts.

**Scenario:**

- You run a stateful workload and must keep data across restarts.

**Hint:** `PersistentVolumeClaim`, `oc set volume`

??? success "Solution"

    ```bash
    # Create a PVC (uses the cluster's default StorageClass)
    cat <<'EOF' | oc apply -f -
    apiVersion: v1
    kind: PersistentVolumeClaim
    metadata:
      name: web-data
    spec:
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: 1Gi
    EOF

    # Mount the PVC into the deployment
    oc set volume deployment/web --add \
      --name=web-data \
      --claim-name=web-data \
      --mount-path=/data

    # Verify it is bound and mounted
    oc get pvc web-data
    POD=$(oc get pod -l app=web -o name | head -1)
    oc exec "$POD" -- df -h /data
    ```

---

## 14. Debug a Failing Pod

Diagnose a pod that will not start and fix it.

**Scenario:**

- A pod is stuck in `ImagePullBackOff` or `CrashLoopBackOff` and you must find
  out why.

**Hint:** `oc get pods`, `oc describe pod`, `oc logs`, `oc get events`

??? success "Solution"

    ```bash
    # Create a broken deployment (non-existent image)
    oc create deployment broken --image=does-not-exist/nope:latest

    # Observe the failing state
    oc get pods -l app=broken

    # Inspect the reason (look at Events at the bottom)
    oc describe pod -l app=broken

    # Check logs (for CrashLoopBackOff) and recent project events
    oc logs -l app=broken --all-containers --previous || true
    oc get events --sort-by=.lastTimestamp | tail

    # Fix by setting a valid image
    oc set image deployment/broken nope=bitnami/nginx:latest
    oc rollout status deployment/broken

    # Clean up
    oc delete deployment/broken
    ```

---

## Cleanup

When you are done practicing, remove the whole project in one command:

```bash
oc delete project demo
```

---

## Next Steps

Return to the [Task Index](README.md) or continue with the numbered
[OpenShift Labs](../README.md).
