# Lab Index

| Lab | Topic | Description |
|-----|-------|-------------|
| [000-SetupToken](000-SetupToken/README.md) | **Getting Started** | Initial OpenShift cluster setup, accessing the web console, and obtaining/using your login token |
| [000-Minishift](000-Minishift/README.md) | **Legacy Setup** | Install a local OpenShift 3.x cluster with Minishift + VirtualBox (script included) |
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
| [013-ConfigMaps-Secrets](013-configmaps-secrets/README.md) | **Configuration** | Managing application configuration with ConfigMaps and Secrets |
| [014-Persistent-Storage](014-persistent-storage/README.md) | **Storage** | Persistent volumes, claims, and storage classes |
| [015-RBAC](015-rbac/README.md) | **Access Control** | Role-based access control and security context constraints |
| [016-Templates](016-templates/README.md) | **Templating** | Creating and using OpenShift templates for application deployment |
| [017-CICD-Pipelines](017-cicd-pipelines/README.md) | **Advanced CI/CD** | Jenkins and Tekton pipelines for automated delivery |
| [018-Network-Policies](018-network-policies/README.md) | **Network Security** | Implementing network policies for pod communication control |
| [019-Quotas-Limits](019-quotas-limits/README.md) | **Resource Management** | Setting resource quotas and limit ranges for projects |
| [020-Health-Probes](020-health-probes/README.md) | **Application Health** | Configuring liveness, readiness, and startup probes |
| [021-Example-Voting-App](021-example-voting-app/README.md) | **Capstone Project** | Deploy a full multi-tier microservices app (vote, redis, worker, db, result) end-to-end |

## Concepts (Primers)

Read these conceptual primers if you want the background theory before the hands-on labs.

| Topic | Description |
|-------|-------------|
| [Architecture Overview](concepts/architecture-overview.md) | Control plane, worker nodes, and OpenShift-specific building blocks |
| [Docker Overview](concepts/docker-overview.md) | Containers, images, and the Docker workflow |
| [Kubernetes Overview](concepts/kubernetes-overview.md) | Pods, Deployments, Services, and the declarative model |
| [OpenShift Management](concepts/openshift-management.md) | Web console, `oc` CLI, and the REST API |

## Appendix

Reference material adapted from the course appendices.

| Appendix | Description |
|----------|-------------|
| [A: Source Code Management](appendix/source-code-management.md) | Git basics and self-hosted GitLab setup |
| [B: CI/CD for Beginners](appendix/cicd-for-beginners.md) | Continuous Integration/Delivery concepts on OpenShift |
| [C: YAML Introduction](appendix/yaml-introduction.md) | YAML syntax primer for writing manifests |
| [D: Environment Setup](appendix/environment-setup.md) | Local cluster options: CRC, MicroShift, Minishift, VirtualBox |
