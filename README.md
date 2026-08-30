# OpenShift Labs

A collection of hands-on labs for learning **Red Hat OpenShift** — covering cluster setup, user management, deployments, networking, storage, CI/CD, and more.

## Prerequisites

- OpenShift cluster (CRC, cloud, or on-premises)
- `oc` CLI installed and configured
- Basic understanding of containers and Kubernetes

## Lab Structure

| Lab | Topic |
|-----|-------|
| 000 | Setup |
| 001 | Verify Cluster |
| 002 | New User |
| 003 | New Project |
| 004 | Docker Lifecycle |
| 005 | Docker Pipeline |
| 006 | Build Hooks |
| 007 | ImageStreams |
| 008 | Deployments |
| 009 | Services & Routes |
| 010 | Monitoring |
| 011 | Logging |
| 012 | Scaling |
| 013 | ConfigMaps & Secrets |
| 014 | Persistent Storage |
| 015 | RBAC |
| 016 | Templates |
| 017 | CI/CD Pipelines |
| 018 | Network Policies |
| 019 | Resource Quotas & Limits |
| 020 | Health Probes |

## Quick Start

```bash
# Clone the repo
git clone https://github.com/nirgeier/OpenShiftLabs.git
cd OpenShiftLabs

# Install mkdocs dependencies
pip install -r requirements.txt

# Serve locally
mkdocs serve
```
