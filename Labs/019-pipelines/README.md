# Lab 019: OpenShift Pipelines — CI/CD with Tekton

## Overview

**OpenShift Pipelines** is the CI/CD solution built into OpenShift, based on the **Tekton** project. It provides Kubernetes-native pipelines that run as Pods in your cluster. Unlike external CI tools (Jenkins, GitHub Actions), Tekton pipelines are defined as Kubernetes resources and execute within the cluster itself.

## Learning Objectives

By completing this lab, you will:

- Install the OpenShift Pipelines Operator
- Understand Tekton concepts (Tasks, Pipelines, PipelineRuns)
- Create and run a simple Pipeline
- Build and deploy an application via a Pipeline
- View pipeline runs and logs

## Prerequisites

- `kubeadmin` access for Operator installation
- Completed Lab 005 (source builds basics)

---

## Background

### Tekton Components

| Component | Description |
|-----------|-------------|
| **Step** | A single command or script running in a container |
| **Task** | A sequence of Steps that run in a single Pod |
| **Pipeline** | An ordered collection of Tasks |
| **PipelineRun** | An execution instance of a Pipeline |
| **TaskRun** | An execution instance of a Task |
| **Workspace** | Shared storage between Tasks in a Pipeline |
| **Trigger** | Automatically starts PipelineRuns (e.g., on Git push) |

### Pipeline Flow

```
Git Push → Trigger → PipelineRun
                         │
                         ├── Task: Clone Source
                         ├── Task: Run Tests
                         ├── Task: Build Image
                         └── Task: Deploy to OpenShift
```

### Tekton vs Jenkins

| Feature | Tekton | Jenkins |
|---------|--------|---------|
| Architecture | Kubernetes-native (CRDs) | External server |
| Execution | Pods in cluster | Jenkins agents |
| Scaling | Kubernetes pod scaling | Jenkins agent scaling |
| Configuration | YAML resources | Groovy/Declarative |
| State | Stateless pipeline runs | Stateful server |

---

## Lab Instructions

### Step 1: Install OpenShift Pipelines Operator

#### Via Web Console

1. Log in as `kubeadmin`
2. **Administrator** → **Operators** → **OperatorHub**
3. Search for **Red Hat OpenShift Pipelines**
4. Click **Install** → Accept defaults → **Install**
5. Wait for status: **Succeeded**

#### Via CLI

```bash
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-pipelines-operator
  namespace: openshift-operators
spec:
  channel: latest
  name: openshift-pipelines-operator-rh
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

# Verify installation
oc get csv -n openshift-operators | grep pipelines
```

---

### Step 2: Install the Tekton CLI (tkn)

```bash
# macOS
brew install tektoncd-cli

# Linux
curl -LO https://github.com/tektoncd/cli/releases/latest/download/tkn_Linux_x86_64.tar.gz
tar xvzf tkn_Linux_x86_64.tar.gz -C /usr/local/bin/ tkn

# Verify
tkn version
```

---

### Step 3: Create a Project and a Simple Task

```bash
oc new-project lab-019-pipelines

# Create a simple Task
cat <<EOF | oc apply -f -
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: hello-task
spec:
  steps:
  - name: say-hello
    image: registry.access.redhat.com/ubi8/ubi-minimal
    command:
    - echo
    args:
    - "Hello from Tekton!"
  - name: show-date
    image: registry.access.redhat.com/ubi8/ubi-minimal
    command:
    - date
EOF

# Run the task
tkn task start hello-task --showlog

# Or via kubectl
cat <<EOF | oc apply -f -
apiVersion: tekton.dev/v1beta1
kind: TaskRun
metadata:
  generateName: hello-task-run-
spec:
  taskRef:
    name: hello-task
EOF
```

---

### Step 4: Create a Task with Parameters

```bash
cat <<EOF | oc apply -f -
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: greet-task
spec:
  params:
  - name: greeting
    type: string
    default: "Hello"
  - name: name
    type: string
    default: "World"
  steps:
  - name: greet
    image: registry.access.redhat.com/ubi8/ubi-minimal
    command:
    - echo
    args:
    - "\$(params.greeting), \$(params.name)!"
EOF

# Run with custom parameters
tkn task start greet-task \
  -p greeting="Shalom" \
  -p name="OpenShift" \
  --showlog
```

---

### Step 5: Create a Build-and-Deploy Pipeline

```bash
# Create a Pipeline that clones, builds, and deploys
cat <<EOF | oc apply -f -
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: build-and-deploy
spec:
  params:
  - name: git-url
    type: string
    description: Git repository URL
  - name: git-revision
    type: string
    default: main
  - name: image-name
    type: string
    description: Image to build
  workspaces:
  - name: shared-workspace
  tasks:
  - name: fetch-source
    taskRef:
      name: git-clone
      kind: ClusterTask
    params:
    - name: url
      value: \$(params.git-url)
    - name: revision
      value: \$(params.git-revision)
    workspaces:
    - name: output
      workspace: shared-workspace
  - name: list-files
    runAfter:
    - fetch-source
    taskRef:
      name: list-directory
    workspaces:
    - name: directory
      workspace: shared-workspace
  - name: build-image
    runAfter:
    - list-files
    taskRef:
      name: buildah
      kind: ClusterTask
    params:
    - name: IMAGE
      value: \$(params.image-name)
    workspaces:
    - name: source
      workspace: shared-workspace
EOF

# Create the helper task
cat <<EOF | oc apply -f -
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: list-directory
spec:
  workspaces:
  - name: directory
  steps:
  - name: list
    image: registry.access.redhat.com/ubi8/ubi-minimal
    command:
    - ls
    args:
    - -la
    - \$(workspaces.directory.path)
EOF
```

---

### Step 6: Run the Pipeline

```bash
# Create a PVC for the workspace
cat <<EOF | oc apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pipeline-workspace
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

# Start the pipeline
tkn pipeline start build-and-deploy \
  -p git-url=https://github.com/openshift/ruby-ex.git \
  -p image-name=image-registry.openshift-image-registry.svc:5000/lab-019-pipelines/ruby-app \
  -w name=shared-workspace,claimName=pipeline-workspace \
  --showlog
```

---

### Step 7: Monitor Pipeline Runs

#### Via CLI

```bash
# List pipeline runs
tkn pipelinerun list

# View logs of a pipeline run
tkn pipelinerun logs <pipelinerun-name> -f

# Describe a pipeline run
tkn pipelinerun describe <pipelinerun-name>
```

#### Via Web Console

1. **Developer** → **Pipelines** (left navigation)
2. Click a Pipeline to see its definition
3. Click **PipelineRuns** tab to see executions
4. Click a PipelineRun to see:
   - Task execution graph
   - Logs for each Task/Step
   - Status and duration

---

### Step 8: Add Triggers (Optional)

Set up automatic pipeline execution on Git push:

```bash
# Create a TriggerTemplate
cat <<EOF | oc apply -f -
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerTemplate
metadata:
  name: build-deploy-trigger
spec:
  params:
  - name: git-repo-url
  - name: git-revision
    default: main
  resourcetemplates:
  - apiVersion: tekton.dev/v1beta1
    kind: PipelineRun
    metadata:
      generateName: build-deploy-run-
    spec:
      pipelineRef:
        name: build-and-deploy
      params:
      - name: git-url
        value: \$(tt.params.git-repo-url)
      - name: git-revision
        value: \$(tt.params.git-revision)
      - name: image-name
        value: image-registry.openshift-image-registry.svc:5000/lab-019-pipelines/app
      workspaces:
      - name: shared-workspace
        persistentVolumeClaim:
          claimName: pipeline-workspace
EOF

# Create an EventListener
cat <<EOF | oc apply -f -
apiVersion: triggers.tekton.dev/v1beta1
kind: EventListener
metadata:
  name: build-deploy-listener
spec:
  triggers:
  - name: github-push
    template:
      ref: build-deploy-trigger
    bindings:
    - name: git-repo-url
      value: \$(body.repository.clone_url)
    - name: git-revision
      value: \$(body.head_commit.id)
EOF

# Expose the EventListener as a Route
oc expose svc el-build-deploy-listener
oc get route el-build-deploy-listener -o jsonpath='{.spec.host}{"\n"}'
# Use this URL as a GitHub webhook
```

---

## Key Concepts

### ClusterTasks vs Tasks

- **ClusterTask**: Available cluster-wide, pre-installed by the Pipelines Operator
- **Task**: Scoped to a namespace, created by users

```bash
# List available ClusterTasks
tkn clustertask list

# Common ClusterTasks:
# - git-clone: Clone a Git repository
# - buildah: Build container images
# - openshift-client: Run oc commands
# - s2i: Source-to-Image builds
```

### Best Practices

1. Use **ClusterTasks** when available instead of writing your own
2. Use **Workspaces** to share data between Tasks (not PipelineResources)
3. Keep Tasks **focused** — one responsibility per Task
4. Use **parameters** to make Pipelines reusable
5. Set **resource limits** on Task steps for predictable scheduling

---

## Validation Checklist

- [ ] Installed OpenShift Pipelines Operator
- [ ] Created and ran a simple Task
- [ ] Created a Pipeline with multiple Tasks
- [ ] Ran a Pipeline and viewed logs
- [ ] Explored Pipeline visualization in the web console
- [ ] Understand Tasks, Pipelines, and PipelineRuns

---

## Clean Up

```bash
tkn pipeline delete build-and-deploy
tkn task delete hello-task greet-task list-directory
oc delete pvc pipeline-workspace
oc delete project lab-019-pipelines
```

---

## Next Lab

Proceed to [Lab 020: Pod Troubleshooting](../020-troubleshooting/README.md) to learn how to diagnose and fix common Pod issues.
