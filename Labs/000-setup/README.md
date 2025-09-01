# Lab 000: Installation and Initial Setup

## Overview

This lab guides you through setting up OpenShift Local (CRC), installing the `oc` CLI tool, and creating your first project. \
We'll learn how to use both the web console and command-line interface.

## Learning Objectives

- Install and start OpenShift Local (CRC)
- Install the `oc` CLI tool
- Access the web console
- Create your first project

## Prerequisites

**System Requirements:**

- **Operating System**: Linux
- **RAM**: Minimum 9 GB RAM (16 GB recommended)
- **CPU**: 4 virtual CPUs minimum
- **Disk Space**: 35 GB of free disk space
- **Virtualization**: Hardware virtualization enabled in BIOS with KVM support

**Software Prerequisites:**

- Administrator/root access on your machine
- A Red Hat account (free to create at https://www.redhat.com)
- Internet connection for downloads
- Web browser (Chrome or Firefox)

---

## Lab Instructions

### Step 1: Install OpenShift Local (CRC) And Get Pull Secret

1. Create a free Red Hat account at https://www.redhat.com
2. Visit https://console.redhat.com/openshift/create/local
3. Download your pull secret (JSON file) - you'll need this during setup

4. Download Linux version of OpenShift Local (CRC) from the same page

5. Extract and install:

   ```bash
   cd ~/Downloads                    # Navigate to Downloads
   tar -xvf crc-linux-*.tar.xz       # Extract the tarball
   cd crc-linux-*-amd64              # Change to extracted directory
   sudo cp crc /usr/local/bin/       # Copy crc binary to /usr/local/bin
   ```

6. Verify installation:

   ```bash
   crc version
   ```

   Expected output:

   ```text
   CRC version: 2.x.x+<commit>
   OpenShift version: 4.x.x
   Podman version: 4.x.x
   ```

7. Run setup:

   ```bash
   crc setup
   ```

   Expected output:

   ```text
   Your system is correctly setup for using CRC. Use 'crc start' to start the instance
   ```

---

### Step 3: Start OpenShift Local

1. Start CRC (takes 10-15 minutes on first run):

   ```bash
   crc start --pull-secret-file ~/Downloads/pull-secret.txt
   ```

   >Note: To allocate more resources (recommended 12 GB RAM, 6 CPUs), \
   use: -crc config set memory 12288 && crc config set cpus 6

   Expected output:

   ```text
      INFO All operators are available. Ensuring stability... 
      INFO Operators are stable (2/3)...                
      INFO Operators are stable (3/3)...                
      INFO Adding crc-admin and crc-developer contexts to kubeconfig... 
      Started the OpenShift cluster.

      The server is accessible via web console at:
      https://console-openshift-console.apps-crc.testing

      Log in as administrator:
      Username: kubeadmin
      Password: 9eXcY-tIBcC-2UsDp-NPW5H  # save this password!

      Log in as user:
      Username: developer
      Password: developer

      Use the 'oc' command line interface:
      $ eval $(crc oc-env)
      $ oc login -u developer https://api.crc.testing:6443
   ```

2. Save the credentials from the output:
   - **Web console**: `https://console-openshift-console.apps-crc.testing`
   - **Admin**: username `kubeadmin`, password shown in output
   - **Developer**: username `developer`, password `developer`

3. Verify it's running:

   ```bash
   crc status
   ```

   Expected output:

   ```text
   CRC VM:          Running
   OpenShift:       Running (v4.x.x)
   Podman:          Running
   ```

---

### Step 4: Install the oc CLI Tool

Add CRC's `oc` to your PATH:

```bash
eval $(crc oc-env)                      # Add to current session
echo 'eval $(crc oc-env)' >> ~/.bashrc  # Persist for future sessions
source ~/.bashrc                        # Reload bashrc
```

Verify:

```bash
oc version
```

Expected output:

```text
   crc status

   CRC VM:          Running
   OpenShift:       Running (v4.19.8)
   RAM Usage:       6.965GB of 16.76GB
   Disk Usage:      29.57GB of 106.8GB (Inside the CRC VM)
   Cache Usage:     30.09GB
   Cache Directory: /home/user/.crc/cache
```

---

### Step 5: Log in to OpenShift via CLI

Log in as developer:

```bash
oc login -u developer -p developer https://api.crc.testing:6443
```

Expected output:

```text
Login successful.

You don't have any projects. You can try to create a new project, by running

    oc new-project <projectname>
```

Verify your login:

```bash
oc whoami
oc get nodes
```

Expected output:

```text
developer

NAME                 STATUS   ROLES                         AGE   VERSION
crc                  Ready    control-plane,master,worker   10m   v1.xx.x
```

---

### Step 6: Access the Web Console

1. Open your browser and navigate to: `https://console-openshift-console.apps-crc.testing`
2. Accept the SSL certificate warning (safe for local development)
3. Log in as `developer` / `developer`
4. You'll see the OpenShift web console home page

   ![alt text](overview.png)

---

### Step 7: Create Your First Project

1. Click **Home** → **Projects** → **Create Project**

   ![alt text](create-project.png)

2. Fill in the details:
   - **Name**: `lab-000-setup`
   - **Display name**: `Getting Started with OpenShift` (optional)

3. Click **Create**

You'll see now be in your new project context.

---

### Step 8: Project Details

#### Understanding Project Tabs

Once your project is created, you'll see several tabs:

| Tab | Purpose |
|-----|---------|
| **Overview** | Dashboard showing project status, recent activity, and alerts |
| **Details** | Project metadata: name, labels, annotations, requester |
| **YAML** | Raw YAML definition of the project resource (editable) |
| **Workloads** | Lists all workloads (Pods, Deployments, etc.) in this project |
| **RoleBindings** | Manage who has access to this project and with what permissions |

![alt text](project-details.png)

> Note: The Overview tab is your go-to for quick health checks. Use RoleBindings when you need to share project access with teammates.

---

## Managing OpenShift Local (CRC)

Useful commands:

```bash
crc stop                    # Stop the cluster
crc start                   # Start the cluster
crc status                  # Check cluster status
crc delete                  # Delete the cluster (removes all data)
crc console --credentials   # View login credentials
crc console                 # Open console in browser
```

---

## Troubleshooting

**Virtualization errors during setup:**

```bash
# Install KVM (Ubuntu/Debian)
sudo apt install qemu-kvm libvirt-daemon libvirt-daemon-system
sudo usermod -aG libvirt $USER
sudo systemctl restart libvirtd
# Log out and back in
```

**Can't access web console:**

- Verify CRC is running: `crc status`
- Check `/etc/hosts` has CRC entries: `cat /etc/hosts | grep crc.testing`
- Accept SSL certificate warning in browser

**oc command not found:**

```bash
eval $(crc oc-env)
```

**Performance issues:**

- Ensure 9GB+ RAM available
- Increase resources if needed:

  ```bash
  crc config set cpus 6
  crc config set memory 12288
  ```

---

## Quick Reference

```bash
# CRC Management
crc start                                                         # Start OpenShift Local
crc stop                                                          # Stop the cluster
crc status                                                        # Check cluster status
crc console --credentials                                         # Show login credentials

# oc CLI
eval $(crc oc-env)                                                # Add oc to PATH
oc login -u developer -p developer https://api.crc.testing:6443   # Log in as developer
oc whoami                                                         # Current user
oc get nodes                                                      # List nodes
oc get projects                                                   # List projects
oc new-project my-project                                         # Create project
```

---

## Next Steps

Continue to [Lab 001: Verify Cluster](../001-verify-cluster/README.md) to learn about cluster health monitoring.
