# Lab 007: ImageStreams and Tagging

## Overview

ImageStreams are an OpenShift abstraction over container images that track tags over time and integrate with the internal registry. This lab teaches you how ImageStreams work, how to tag and promote images, and how builds flow into deployments.

## Learning Objectives

By completing this lab, you will:

- Understand ImageStreams, ImageStreamTags, and their role in deployments
- Create a BuildConfig that outputs to an ImageStream
- Tag images for promotion (e.g., latest → stable)

## Prerequisites

- Completed Lab 005 (have an app like `devfile-sample` deployed)
- A project to work in (e.g., `lab-003-demo` from Lab 003)

---


## Background: What is an ImageStream?

- Tracks images by tags (e.g., `latest`, `stable`)
- Decouples your app’s reference from the actual image location
- Can be referenced by Deployments; when you update the tag, you can perform a rollout to use the new image

Common patterns:
- Build → Output to `ImageStream:latest`
- Promotion → `latest` tagged to `stable` after validation
- Deployments reference `stable` to ensure controlled releases

### Key Terms
- ImageStream (IS): OpenShift resource that tracks one or more image references over time.
- ImageStreamTag (ISTag): A specific tag of an ImageStream (e.g., `devfile-sample:stable`). Often used by Deployments to pin releases.
- Tag: A label pointing to a particular image digest. Tagging can copy or reference images across streams (promotion).
- Promotion: Moving a tested image from a development tag (e.g., `latest`) to a release tag (e.g., `stable`).
- Rollout: Updating Pods to a new image or configuration; ensure Deployments point to the intended ISTag before rolling out.

---

## Lab Instructions

### Step 1: Create or Verify Build Output to ImageStream

In the web console (Developer → Add → Import from Git), create an app from:
```
https://github.com/nodeshift-starters/devfile-sample.git
```
- Ensure a BuildConfig is created and outputs to an ImageStream named `devfile-sample`.
- Confirm a Deployment references that ImageStream.

Web console steps:
1. Switch to Developer perspective and select your project (e.g., `lab-003-demo`).
2. Click **+Add** → **Import from Git**.
3. Enter the Git URL above and wait for detection.
4. Resource type: **Deployment**; check **Create a route** (optional).
5. Under **Build configuration**, verify output points to an ImageStream (name `devfile-sample`).
6. Click **Create** and observe the Build and Deployment in **Topology**.

### Step 2: Inspect ImageStreams

In Administrator perspective:
- Go to Builds → ImageStreams
- Find `devfile-sample` and open it
- Review tags (e.g., `latest`) and image metadata

Web console steps:
1. Switch to Administrator perspective.
2. Navigate to **Builds** → **ImageStreams**.
3. Click `devfile-sample` to view details and tags.

### Step 3: Promote via Tagging

Use tagging to promote a known-good image:
1. After a successful build, tag `latest` to `stable`
2. Ensure your Deployment references `stable` (optional: adjust if currently using `latest`)

Web console steps:
1. Administrator perspective → **Builds** → **ImageStreams** → `devfile-sample`.
2. Click **Add tag** (or **Actions** → **Add tag**) and set:
	- From: `latest`
	- To: `stable`
3. Save. Confirm `stable` now appears in the ImageStream tags list.
4. If your Deployment should use `stable`, edit the Deployment’s image reference to point to `ImageStreamTag` `devfile-sample:stable`.

### Step 4: Roll Out Using Promoted Tag

Update your Deployment to reference `stable` (if it does not already), then roll out the new version and validate in Topology.

Web console steps:
1. Developer perspective → **Topology** → click your Deployment.
2. **Actions** → **Edit Deployment**.
	- Under container image, choose **Use image stream tag** (or select from image source) if available.
	- Select your ImageStream (e.g., `devfile-sample`) and the tag (e.g., `stable`).
	- Alternatively, manually set the image reference to `ImageStreamTag devfile-sample:stable`.
3. Save changes; the rollout starts automatically.
4. Watch pods update and verify the app via the Route link.

---

## CLI Option: Using oc

Manage ImageStreams and tags from the CLI. This sequence creates an S2I app (producing a BuildConfig and ImageStream), inspects ImageStreams, tags an image for promotion, lists resulting tags, and restarts the deployment to pick up changes:

```bash
oc new-app https://github.com/nodeshift-starters/devfile-sample.git --name=devfile-sample --strategy=source
oc get is
oc describe is/devfile-sample
oc tag devfile-sample:latest devfile-sample:stable
oc get istag
oc rollout restart deploy/devfile-sample
```

---

## Validation Checklist

- ImageStream `devfile-sample` exists with `latest` tag
- Tag `stable` created and points to expected image
- Deployment updated when tag changes (if referencing `stable`)
- Application accessible and working after rollout

---

## Clean Up (Optional)

- Remove the `stable` tag if desired: `oc tag -d devfile-sample:stable`
- Delete the application: remove Deployment, Service, and ImageStream from Topology


---

## Next Lab

Continue to [Lab 008: Deployments and DeploymentConfig](../008-deploying/README.md) to compare deployment types, configure probes, perform rollouts, and scale your application.
