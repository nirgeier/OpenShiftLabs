# Lab 003: Working with OpenShift Projects

## Overview

In OpenShift, a **project** is a Kubernetes namespace with additional security and management features. If you're familiar with Kubernetes namespaces, think of projects as namespaces plus RBAC (Role Based Access Control) policies, network isolation, and resource tracking. This lab aligns with the setup performed in earlier labs and focuses on reviewing and managing existing projects rather than creating new ones.  

## Learning Objectives

By completing this lab, you will:

- Understand how OpenShift projects extend Kubernetes namespaces
- Review projects created in earlier labs
- Navigate between projects and understand project context
- Explore project settings and access controls

## Prerequisites

- Access to an OpenShift cluster (Developer Sandbox or self-hosted)
- Familiarity with Kubernetes concepts (namespaces, pods, deployments)
- Basic understanding of Docker and containerization
- Web browser to access the OpenShift console

---

## Background: Projects vs Namespaces

**What you know from Kubernetes:**
- Namespaces provide logical isolation for resources
- Resources are scoped to namespaces
- RBAC policies can be applied per namespace

**OpenShift Projects add:**
- User-friendly management through the console
- Automatic RBAC policy creation
- Network isolation by default (NetworkPolicies)
- Resource quotas and limits (can be applied)
- Project-level annotations and metadata

**Key point**: A project IS a namespace with extra features. When you create a project named `my-project`, you get a namespace called `my-project` plus additional OpenShift-specific resources.

---

## Lab Instructions

### Step 1: Access the OpenShift Web Console

1. Navigate to your OpenShift console URL in a web browser
2. Log in with your credentials
3. You'll land on the cluster overview dashboard

**Note**: Unlike vanilla Kubernetes, OpenShift provides a built-in web console for all cluster interactions.

---

### Step 2: Switch to Developer Perspective

OpenShift console has two perspectives:
- **Administrator**: Cluster-wide operations (similar to `kubectl` with cluster-admin)
- **Developer**: Application-focused view (project-scoped operations)

**Switch to Developer:**
1. Click the perspective switcher in the top-left corner
2. Select **Developer**

This view is optimized for deploying and managing applications within your projects.

---

### Step 3: Review Existing Projects (from Labs 000 and 002)

In previous labs you already created projects such as `lab-000-setup`, `rbac-demo`, and `team-project`.

1. Open the **Project** dropdown near the top of the console
2. Select an existing project, for example **team-project**
3. Switch between projects to observe how the context changes in the Developer view

Optional: If your environment does not have these projects yet, you can create one using the console’s **Create Project** flow and name it appropriately for your exercises.

---

### Step 3.1: Create a Project for the Next Lab

Lab 004 will deploy an application into a project. If you don’t already have a suitable project, create one now:

1. In the Developer perspective, open the **Project** dropdown
2. Click **Create Project**
3. Enter:
  - Name: `lab-003-demo`
  - Display Name: `Lab 003 Demo`
  - Description: `Project for Lab 004 deployment`
4. Click **Create**

You’ll use `lab-003-demo` in Lab 004.

### Step 4: Verify Project Resources

While still in the web console, let's see what OpenShift created:

1. Click **Project** in the left navigation
2. View the **Details** tab:
   - Status: Active
  - Name: your selected project (e.g., `team-project`)
   - Labels and annotations

3. Click the **Project Access** tab:
  - You'll see who has roles in this project (e.g., `developer` with `edit` in `team-project` from Lab 002)
  - Similar to having namespace-admin RBAC in Kubernetes

---

## What's Next?

Now that you have a project (namespace), you're ready to deploy workloads! In the upcoming labs, you'll:
- Deploy container images (like `docker run`)
- Create Kubernetes Deployments and Services
- Build images from source using OpenShift BuildConfigs
- Expose services externally with Routes

Continue to [Lab 004: Deploying Your First Application](../004-docker-lifecycle/README.md) where you'll deploy a container image to one of your existing projects.

---

## CLI Option: Using oc

Prefer the CLI? The first sequence reviews an existing project; the second creates the `lab-003-demo` project for Lab 004 and verifies it:

```bash
oc projects
oc project team-project
oc get project team-project
oc get rolebindings -n team-project
oc describe project team-project
```

```bash
oc new-project lab-003-demo --display-name="Lab 003 Demo" --description="Project for Lab 004 deployment"
oc project lab-003-demo
oc get project lab-003-demo
oc get rolebindings -n lab-003-demo
```

