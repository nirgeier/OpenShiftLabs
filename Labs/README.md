# OpenShift Labs

## About OpenShift

Red Hat OpenShift is an enterprise-ready Kubernetes container platform that provides a complete application platform for developing and deploying containerized applications. Built on proven open-source technologies, OpenShift extends Kubernetes with developer and operations-centric tools that enable:

- **Automated Operations**: Streamlined installation, upgrades, and lifecycle management
- **Developer Productivity**: Integrated CI/CD pipelines, source-to-image builds, and developer workflows
- **Enterprise Security**: Built-in security scanning, policy enforcement, and compliance controls
- **Hybrid Cloud Flexibility**: Consistent experience across on-premises, public cloud, and edge environments

## Learning Path Overview

This structured curriculum takes you from initial cluster setup through advanced operational practices. Each lab builds upon previous concepts, providing a progressive learning experience suitable for developers, operators, and architects who want to master OpenShift.

### What You'll Learn

Throughout these tutorials, you'll gain practical experience with:

- **Infrastructure Management**: Cluster setup, health verification, and resource management
- **Identity & Access**: User management, RBAC configuration, and project isolation
- **Application Deployment**: Container lifecycle, build strategies, and deployment patterns
- **CI/CD Integration**: Automated pipelines, webhooks, and continuous delivery workflows
- **Networking & Exposure**: Services, routes, ingress controllers, and load balancing
- **Operations & Observability**: Monitoring, logging, alerting, and autoscaling

## Hands-On Labs

| Lab | Topic | Description |
|-----|-------|-------------|
| [000-Setup](000-setup/README.md) | **Getting Started** | Initial OpenShift cluster setup and accessing the web console |
| [001-Verify-Cluster](001-verify-cluster/README.md) | **Health & Status** | Verify cluster health, check nodes, operators, and resource availability |
| [002-New-User](002-new-user/README.md) | **Identity Management** | Creating and managing users, roles, and RBAC configurations |
| [003-New-Project](003-new-project/README.md) | **Resource Isolation** | Creating namespaces/projects with resource quotas and limits |
| [004-Docker-Lifecycle](004-docker-lifecycle/README.md) | **Container Basics** | Building, tagging, pushing, and managing local Docker images |
| [005-Docker-Pipeline](005-docker-pipeline/README.md) | **CI/CD Foundations** | Building automated pipelines from source code to container images |
| [006-Hooks-Setup](006-hooks-setup/README.md) | **Automation Triggers** | Configuring Git hooks, build hooks, and webhooks for CI triggers |
| [007-Images-ImageStream](007-images-imagestream/README.md) | **Image Management** | Working with BuildConfigs, ImageStreams, and registry interactions |
| [008-Deploying](008-deploying/README.md) | **Deployment Strategies** | Understanding Deployments vs DeploymentConfigs, scaling and rollouts |
| [009-Services-Routes](009-services-routes/README.md) | **Network Exposure** | Exposing applications using Services, Routes, and Ingress controllers |
| [010-Monitoring](010-monitoring/README.md) | **Observability** | Implementing monitoring and alerting with Prometheus and Grafana |
| [011-Logging](011-logging/README.md) | **Log Aggregation** | Centralized logging with EFK/ELK stack for troubleshooting and analysis |
| [012-Scaling](012-scaling/README.md) | **Performance Tuning** | Horizontal Pod Autoscaling (HPA) and manual scaling strategies |

## Prerequisites

Before starting these labs, ensure you have:

- Access to an OpenShift cluster (CRC, cloud provider, or on-premises installation)
- Basic understanding of container concepts and Kubernetes fundamentals

## How to Use These Labs

Each lab is self-contained and includes:

- **Learning Objectives**: Clear goals for what you'll accomplish
- **Prerequisites**: Required knowledge and completed previous labs
- **Step-by-Step Instructions**: Detailed commands with explanations
- **Validation Steps**: How to verify successful completion
- **Troubleshooting Tips**: Common issues and solutions

We recommend following the labs sequentially, as concepts and configurations build upon each other. However, experienced users may skip to specific topics of interest.

---

**Ready to begin?** Start with [Lab 000: Setup](000-setup/README.md) to configure your OpenShift environment.

