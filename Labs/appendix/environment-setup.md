# Appendix D: Environment Setup (Local Cluster)

> Maps to the video course *"APPENDIX D – Setup VirtualBox"*.
> The course uses VirtualBox + Minishift. This appendix covers that plus the
> modern equivalents so you can run a local OpenShift cluster on any machine.

## Options at a glance

| Tool | Best for | Notes |
|---|---|---|
| **CRC (OpenShift Local)** | Recommended today | Full single-node OpenShift 4.x |
| **MicroShift** | Lightweight / edge / macOS | Small footprint, fast |
| **Minishift** | The course's original tool | OpenShift 3.x, now legacy |
| **VirtualBox** | The hypervisor Minishift ran on | Still fine for VMs |

> This repository already provides setup scripts - see
> [Lab 000: Setup & Token](../000-SetupToken/README.md) and its
> `install-openshift-local.sh` / `install-microshift-mac.sh` helpers.

## Option 1: VirtualBox + Minishift (course version)

### Install VirtualBox
VirtualBox is a free hypervisor that runs the VM your cluster lives in.

1. Download from <https://www.virtualbox.org/wiki/Downloads> for your OS.
2. Install and reboot if prompted.
3. Verify:

   ```bash
   VBoxManage --version
   ```

### Install Minishift

```bash
# macOS (Homebrew)
brew install minishift

# Start a single-node OpenShift 3.x cluster on VirtualBox
minishift start --vm-driver virtualbox

# Point your shell at the cluster's oc
eval $(minishift oc-env)

# Open the web console
minishift console
```

> Minishift ships OpenShift 3.x. For OpenShift 4.x features used in these labs,
> prefer CRC below.

## Option 2: CRC / OpenShift Local (recommended)

CRC runs a full single-node **OpenShift 4.x** cluster in a local VM.

```bash
# 1. Download CRC for your OS from:
#    https://console.redhat.com/openshift/create/local

# 2. Prepare the host (checks virtualization, sets up networking)
crc setup

# 3. Start the cluster (needs your free Red Hat pull secret)
crc start

# 4. Configure your shell to use crc's oc
eval $(crc oc-env)

# 5. Log in as the developer or admin user
crc console --credentials
oc login -u developer -p developer https://api.crc.testing:6443
```

**Minimum resources:** ~4 vCPUs, 9 GB RAM, 35 GB disk (more is better).

## Option 3: MicroShift (lightweight, macOS-friendly)

Good when you want something smaller than CRC. This repo includes
`install-microshift-mac.sh` in [Lab 000](../000-SetupToken/README.md).

## Verifying any setup

```bash
oc whoami                 # confirm you're logged in
oc get nodes              # cluster node(s) should be Ready
oc get clusteroperators   # (CRC) operators should be Available
```

Once `oc get nodes` shows a `Ready` node, continue to
[Lab 001: Verify Cluster](../001-verify-cluster/README.md).

## Troubleshooting

| Problem | Fix |
|---|---|
| `crc start` fails on virtualization | Enable VT-x/AMD-V in BIOS |
| Not enough memory | Raise with `crc config set memory 12288` |
| `oc` not found after start | Run `eval $(crc oc-env)` / `eval $(minishift oc-env)` |
| Pull secret errors | Re-download from the Red Hat console and pass to `crc start` |
