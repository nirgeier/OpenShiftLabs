# Lab 000b: Installing OpenShift with Minishift

## Overview

This lab sets up a local, single-node OpenShift cluster using **Minishift** -
the tool used in the original *OpenShift for the Absolute Beginners* course.
Minishift runs **OpenShift 3.11** inside a virtual machine managed by a
hypervisor (VirtualBox by default).

> **Heads-up:** Minishift is a **legacy** tool. Its last release (`v1.34.3`) is
> from 2019 and it ships OpenShift 3.x. For OpenShift **4.x**, use
> [Lab 000: Setup & Token](../000-SetupToken/README.md) (CRC) or the MicroShift
> path instead. This lab exists so you can follow along with the original
> course and understand the Minishift workflow.

## Learning Objectives

- Understand what Minishift is and how it differs from CRC/MicroShift
- Install a hypervisor (VirtualBox) and the `minishift` binary
- Start a single-node OpenShift 3.x cluster
- Access the cluster via the web console and the `oc` CLI
- Manage the cluster lifecycle (start, stop, delete)

## Prerequisites

**System Requirements:**

- **Operating System**: macOS (Intel) or Linux
- **Architecture**: `x86_64` / `amd64` (Minishift has **no** Apple Silicon/ARM build)
- **RAM**: 4 GB free minimum (8 GB+ recommended)
- **Disk**: 20 GB free
- **Virtualization**: Hardware virtualization enabled in BIOS/UEFI

**Software Prerequisites:**

- A supported hypervisor - **VirtualBox** (recommended, cross-platform),
  KVM (Linux), or HyperKit (macOS)
- `curl` or `wget`
- Internet connection

> **Apple Silicon (M1/M2/M3) users:** Minishift will not run natively. Use
> [CRC](../000-SetupToken/README.md) or MicroShift instead.

---

## Quick Start (Script)

The [`install-minishift.sh`](install-minishift.sh) script automates the whole
process: platform detection, hypervisor check, download, install, PATH setup,
and cluster start.

```bash
cd Labs/000-Minishift
chmod +x install-minishift.sh
./install-minishift.sh
```

Override defaults with environment variables:

```bash
# Use KVM on Linux with more resources
MINISHIFT_VM_DRIVER=kvm VM_CPUS=4 VM_MEMORY_MB=8192 ./install-minishift.sh
```

| Variable | Default | Purpose |
|---|---|---|
| `MINISHIFT_VERSION` | `1.34.3` | Minishift release to install |
| `MINISHIFT_VM_DRIVER` | `virtualbox` | Hypervisor driver (`virtualbox`, `kvm`, `hyperkit`) |
| `VM_CPUS` | `2` | vCPUs for the VM |
| `VM_MEMORY_MB` | `4096` | Memory for the VM (MB) |
| `VM_DISK_GB` | `20` | Disk size for the VM (GB) |
| `BIN_DIR` | `~/.local/bin` | Where the `minishift` binary is installed |

---

## Manual Steps

Prefer to do it by hand? Follow these steps.

### Step 1: Install VirtualBox

VirtualBox is the hypervisor that hosts the Minishift VM.

- **macOS:** `brew install --cask virtualbox` (or download from
  <https://www.virtualbox.org/wiki/Downloads>)
- **Linux (Fedora/RHEL):** install from the VirtualBox repo or your distro
- Verify:

  ```bash
  VBoxManage --version
  ```

### Step 2: Download and Install Minishift

```bash
# Pick your platform: darwin-amd64 or linux-amd64
VERSION=1.34.3
OS=darwin   # or: linux

curl -fSL -o minishift.tgz \
  "https://github.com/minishift/minishift/releases/download/v${VERSION}/minishift-${VERSION}-${OS}-amd64.tgz"

tar -xzf minishift.tgz
mkdir -p ~/.local/bin
cp minishift-${VERSION}-${OS}-amd64/minishift ~/.local/bin/
chmod +x ~/.local/bin/minishift
export PATH="$PATH:$HOME/.local/bin"
```

Verify:

```bash
minishift version
```

### Step 3: Start the Cluster

```bash
minishift start --vm-driver virtualbox --cpus 2 --memory 4096 --disk-size 20GB
```

The first start downloads the OpenShift ISO and boots the VM - this takes a few
minutes.

### Step 4: Access the Cluster

```bash
# Point your shell at Minishift's bundled oc client
eval $(minishift oc-env)

# Open the web console in a browser
minishift console

# Log in from the CLI (default credentials)
oc login -u developer -p developer $(minishift ip):8443
```

Default credentials:

- **Username:** `developer`
- **Password:** `developer`

---

## Validation Checklist

- `minishift status` reports the cluster is **Running**
- `minishift console` opens the OpenShift web console
- `oc whoami` returns `developer` after login
- `oc get nodes` shows one `Ready` node

## Lifecycle Commands

```bash
minishift status     # Show status
minishift stop       # Stop the VM (preserves state)
minishift start      # Start it again
minishift delete     # Delete the VM entirely
```

## Troubleshooting

| Problem | Fix |
|---|---|
| `Minishift only provides amd64 builds` | You are on ARM/Apple Silicon - use CRC or MicroShift |
| `VBoxManage: command not found` | Install VirtualBox and ensure it is on your PATH |
| VM fails to start (VT-x/AMD-V) | Enable hardware virtualization in BIOS/UEFI |
| `minishift: command not found` | Run `export PATH="$PATH:$HOME/.local/bin"` |
| Download 404 | Check `MINISHIFT_VERSION`; valid latest is `1.34.3` |

## Next

Once your cluster is up, continue with
[Lab 001: Verify Cluster](../001-verify-cluster/README.md), or compare local
cluster options in
[Appendix D: Environment Setup](../appendix/environment-setup.md).
