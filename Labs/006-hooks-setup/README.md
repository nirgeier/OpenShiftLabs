# Lab 006: Webhooks and Automated Builds

## Overview

In Lab 005, you manually triggered builds by clicking "Start Build". In real CI/CD workflows, builds should trigger automatically when developers push code changes. This lab teaches you to configure **webhooks** that automatically start OpenShift builds whenever code is pushed to your Git repository.

## Learning Objectives

By completing this lab, you will:

- Understand the concept of webhooks in OpenShift CI/CD
- Learn how BuildConfig webhooks trigger builds on code push

## Prerequisites

- Completed Lab 005 (have a BuildConfig created)
- Familiarity with SCM concept (github, bitbucket)
- Understanding of CI/CD concepts

---

## Background: Webhooks in CI/CD

**Traditional workflow (manual):**
1. Developer pushes code to Git
2. Someone manually triggers build
3. Wait for build to complete
4. Manually deploy if needed

**Automated workflow (webhooks):**
1. Developer pushes code to Git
2. Git server sends webhook to OpenShift
3. OpenShift automatically starts new build
4. On success, automatically redeploys application

---

## Lab Instructions 

This lab is conceptual and requires no actions. The summary below explains how webhooks fit into OpenShift builds and deployments.

# Understanding Webhooks

## What and Why 
- A webhook is a simple message sent by your Git server to OpenShift when you push code.
- OpenShift uses that message to automatically start a new Build.
- After a successful Build, OpenShift updates the image in an ImageStream and rolls out your Deployment.
- Benefit: fewer manual clicks and faster feedback after each commit.

## How It Works 
1. You push code to GitHub/GitLab.
2. The Git platform sends an HTTP POST (the webhook) to your BuildConfig’s webhook URL.
3. OpenShift checks the secret embedded in the URL to verify the request.
4. A Build starts; if it completes, your app is redeployed with the new image.

## Quick Setup (Optional)
- In OpenShift: BuildConfig → Webhooks → copy the GitHub webhook URL with secret.
- In your own Git repo: Settings → Webhooks → Add webhook → paste the URL.
- Push a commit to test; the Build should start automatically if permissions are correct.

---

## CLI Option: Using oc

Useful Build webhook and automation commands. This sequence shows webhook details for a `BuildConfig`, triggers a build (as a webhook would), and waits for the deployment rollout:

```bash
oc get bc/devfile-sample -o jsonpath='{.spec.triggers[?(@.type=="GitHub")]..github.secret}{"\n"}'
oc describe bc/devfile-sample | sed -n '/Webhooks/,$p'
oc start-build devfile-sample --wait --follow
oc rollout status deploy/devfile-sample
```

## Next
- Continue to [Lab 007: Image Streams and Tagging](../007-images-imagestream/README.md).
