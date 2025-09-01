# Lab 005: Building Applications from Source Code

## Overview

Instead of building container images locally with `docker build`, OpenShift can build images directly from your source code repository. This lab introduces **Source-to-Image (S2I)** builds, where you provide a Git URL and OpenShift handles the entire build process - no Dockerfile required.

## Learning Objectives

By completing this lab, you will:

- Deploy an application directly from a Git repository
- Understand Source-to-Image (S2I) build process
- Work with BuildConfigs and ImageStreams
- Trigger rebuilds when code changes
- View build logs and troubleshoot build failures

## Prerequisites

- Completed Lab 003 (have a project created)
- Completed Lab 004 (understand deployments and routes)
- Familiarity with Git repositories
- Understanding of Docker image building concepts
- Access to OpenShift web console

---

## Background: Source-to-Image (S2I)

**Traditional Docker workflow:**
1. Write application code
2. Create Dockerfile
3. Run `docker build -t myapp .`
4. Push to registry
5. Deploy image

**OpenShift S2I workflow:**
1. Write application code (no Dockerfile needed)
2. Push to Git repository
3. OpenShift detects language, builds image automatically
4. Deploys the built image
5. Sets up automatic rebuilds on code changes

**How S2I Works:**
- OpenShift uses **builder images** (e.g., `python:3.9`, `nodejs:16`)
- Builder image contains tools to compile/build your application
- Your source code is injected into the builder
- Produces a new image with your application ready to run
- No Dockerfile required (but you can use one if needed)

---

## Lab Instructions

### Step 1: Prepare Your Project

1. Open OpenShift web console
2. Switch to **Developer** perspective
3. Select your project (e.g., `lab-003-demo`)
4. Navigate to **Topology** view

---

### Step 2: Deploy from Git Repository

We'll deploy a sample Node.js application from GitHub.

1. Click **+Add** in the left navigation

2. Select **Import from Git** tile

3. **Git Repo URL**: Enter the following:
   ```
   https://github.com/nodeshift-starters/devfile-sample.git
   ```
   - This is a sample Node.js application repository

4. OpenShift analyzes the repository:
   - **Detects**: Node.js application
   - **Builder Image**: nodejs (automatically selected)
   - **Builder Image Version**: latest available

5. Review the detected settings:
   - **Application**: Create new "devfile-sample-app"
   - **Name**: `devfile-sample`
   - **Resources**: Deployment
   - **Create a route**: ✅ Checked

6. **Build Configuration** (expand to see):
   - **Build Strategy**: Source-to-Image (S2I)
   - **Builder Image**: nodejs (version as detected)
   - Shows detected start command

7. Click **Create**


---

### Step 3: Watch the Build Process

1. You're redirected to **Topology** view
2. Notice your application shows a different icon (build in progress)
3. Click on the application circle

4. In the right panel, click the **Resources** tab:
   - **Builds** section shows "devfile-sample-1 Running"
   - Click on the build name: `devfile-sample-1`

5. You're taken to the **Build Details** page:
   - **Status**: Running → Complete
   - **Duration**: How long the build took
   - **Output image**: Where the built image is stored

6. Click the **Logs** tab to see build output:
   ```
   Cloning repository...
   Pulling builder image...
   Installing dependencies (npm install)...
   Building application...
   Pushing image to registry...
   Build complete!
   ```
   - Similar to watching `docker build` output

---

### Step 4: Verify the Deployment

Once the build completes, OpenShift automatically deploys the built image.

1. Return to **Topology** view
2. The application circle should now be dark blue (running)
3. Pod count shows 1/1

4. Click the Route icon (↗) to open the application
5. You should see the Node.js Express welcome page

---

### Step 5: Explore BuildConfig and ImageStream

**View BuildConfig:**
1. Click **Builds** in the left navigation
2. See your `devfile-sample` BuildConfig
3. Click on it to see details:
   - **Git Repository**: Source code location
   - **Builder Image**: Base image used for building
   - **Output**: Target ImageStream
    - **Triggers**: What causes a rebuild (config change, image change, webhook)
       - Note: Webhooks require write access to the Git repository. If you don't own the repo, you can rely on manual builds from the console (Actions → Start Build).

**View ImageStream:**
1. Click **ImageStreams** (under Builds section)
2. See `devfile-sample` ImageStream
3. Click on it:
   - **Tags**: Lists image versions (similar to Docker tags)
   - **latest**: Points to most recent build
   - **Image ID**: Unique SHA256 identifier

**Understanding ImageStreams:**
- Track changes to images over time
- Act as pointer to images in registry
- Can trigger automatic deployments on updates
- Provide stable reference even if underlying image changes

---

### Step 6: Trigger a New Build

You can manually trigger rebuilds (useful for getting latest code).

1. Go to **BuildConfig** → Click `devfile-sample` 
2. Click **Actions** dropdown (top-right)
3. Select **Start Build**

4. A new build starts: `devfile-sample-2`
5. On the **Builds** section, Click on the new build to watch logs

6. After completion:
   - ImageStream updated with new image
   - Deployment automatically rolls out new version
   - Old pod terminated, new pod starts

**This is continuous deployment in action!**

---

### Step 7: View Build History

1. Navigate to **Builds** → `devfile-sample`
2. Click **Builds** tab
3. See all builds: `devfile-sample-1`, `devfile-sample-2`, etc.
4. Each build shows:
   - Status: Complete, Failed, Cancelled
   - Duration: Build time
   - Commit: Git commit that triggered it (if webhook configured)

---

### Step 8: Troubleshoot a Failed Build (Optional)

Let's intentionally cause a build failure to practice troubleshooting:

1. Go to **Builds** → `devfile-sample` BuildConfig
2. Click **Actions** → **Edit BuildConfig**
3. Find the Git repository URL
4. Change it to an invalid URL: `https://github.com/invalid/repo.git`
5. Click **Save**

6. Click **Actions** → **Start Build**
7. Watch the build fail
8. Check the logs:
   - Shows error: "Repository not found"
   - This is how you debug build issues

9. **Fix it**: Edit BuildConfig again, restore correct URL
10. Start a new build - should succeed

---


## CLI Option: Using oc

Perform common S2I build and deploy actions via CLI. This sequence switches to your project, creates an S2I app from Git, tails the first build logs, inspects build/deploy resources, triggers another build, exposes a route, and prints the application URL:

```bash
oc project lab-003-demo
oc new-app https://github.com/nodeshift-starters/devfile-sample.git --name=devfile-sample --strategy=source
oc logs -f build/devfile-sample-1
oc get is
oc get deploy
oc start-build devfile-sample --wait --follow
oc expose svc/devfile-sample
oc get route devfile-sample -o jsonpath='{.spec.host}{"\n"}'
```



---

## Key Concepts

### BuildConfig
- Defines how to build your application
- Specifies source (Git repo), builder image, output
- Like a CI pipeline configuration
- Can have multiple strategies: S2I, Docker, Custom

### Build
- Execution instance of a BuildConfig
- Each build has logs, status, output image
- Numbered sequentially: build-1, build-2, etc.
- Similar to CI job runs (Jenkins, GitHub Actions)

### ImageStream
- Tracks image versions over time
- Acts as abstraction over image registries
- Provides tags (latest, v1, v2, etc.)
- Enables automatic redeployment on image updates

### Source-to-Image (S2I)
- Build strategy that doesn't require Dockerfile
- Uses pre-built builder images with best practices
- Supports: Node.js, Python, Ruby, Java, PHP, .NET, Go
- Faster than Dockerfile builds (uses caching)

---

## Build Strategies Comparison

| Strategy | Use Case | Requires Dockerfile |
|----------|----------|--------------------|
| **Source-to-Image** | Standard apps (Node, Python, Java) | No |
| **Docker** | Custom build requirements | Yes |


---

## Next Steps

Continue to [Lab 006: Webhooks and Automated Builds](../006-hooks-setup/README.md) to learn how to automatically trigger builds when you push code changes to Git.

