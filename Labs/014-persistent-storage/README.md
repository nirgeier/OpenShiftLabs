# Lab 014: Persistent Storage — PV & PVC

## Overview

Containers are ephemeral — when a Pod is deleted or restarted, all data inside is lost. **Persistent Volumes (PV)** and **Persistent Volume Claims (PVC)** allow you to attach durable storage to Pods that survives restarts, rescheduling, and even Pod deletion. This is essential for databases, file uploads, and any stateful application.

## Learning Objectives

By completing this lab, you will:

- Understand the PV/PVC storage model
- Create PersistentVolumeClaims to request storage
- Mount persistent storage into Pods
- Understand StorageClasses and dynamic provisioning
- Verify data persistence across Pod restarts

## Prerequisites

- Completed Lab 013 (ConfigMaps & Secrets)
- A running OpenShift cluster (CRC includes a default StorageClass)

---

## Background

### Storage Model

```
Administrator creates    Developer requests    Pod uses
┌────────────┐          ┌──────────────┐      ┌──────────┐
│ PersistentVolume│◄────│ PersistentVolumeClaim│◄────│  Pod     │
│ (PV)       │  binds   │ (PVC)        │ mounts│          │
└────────────┘          └──────────────┘      └──────────┘

With dynamic provisioning (StorageClass), the PV is created automatically.
```

### Key Terms

| Term | Description |
|------|-------------|
| **PersistentVolume (PV)** | A piece of storage provisioned by an admin or dynamically |
| **PersistentVolumeClaim (PVC)** | A request for storage by a developer |
| **StorageClass** | Defines the type of storage (fast SSD, standard HDD, NFS) |
| **Access Modes** | How the volume can be mounted |
| **Reclaim Policy** | What happens to PV when PVC is deleted |

### Access Modes

| Mode | Abbreviation | Description |
|------|--------------|-------------|
| ReadWriteOnce | RWO | Mounted read-write by a single node |
| ReadOnlyMany | ROX | Mounted read-only by many nodes |
| ReadWriteMany | RWX | Mounted read-write by many nodes |

---

## Lab Instructions

### Step 1: Create a Project

```bash
oc new-project lab-014-storage
```

### Step 2: Explore Available StorageClasses

```bash
# List StorageClasses
oc get storageclass

# Describe the default StorageClass
oc describe storageclass $(oc get storageclass -o jsonpath='{.items[0].metadata.name}')
```

In CRC, the default StorageClass is typically `crc-csi-hostpath-provisioner`.

---

### Step 3: Create a PersistentVolumeClaim

#### Via CLI

```bash
cat <<EOF | oc apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-data-pvc
  namespace: lab-014-storage
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

# Verify the PVC
oc get pvc
```

Expected output:
```
NAME          STATUS   VOLUME    CAPACITY   ACCESS MODES   STORAGECLASS
my-data-pvc   Bound    pvc-xxx   1Gi        RWO            crc-csi-hostpath-provisioner
```

#### Via Web Console

1. **Administrator** → **Storage** → **PersistentVolumeClaims**
2. Click **Create PersistentVolumeClaim**
3. Fill in:
   - Name: `my-data-pvc-ui`
   - Access Mode: Single User (RWO)
   - Size: 1 GiB
4. Click **Create**

---

### Step 4: Deploy an App with Persistent Storage

```bash
# Deploy a simple app
oc new-app docker.io/nirgeier/simple-web-app:latest --name=storage-demo

# Add the PVC as a volume mount
oc set volume deploy/storage-demo \
  --add \
  --type=persistentVolumeClaim \
  --claim-name=my-data-pvc \
  --mount-path=/data \
  --name=data-volume

# Wait for pod to be ready
oc rollout status deploy/storage-demo
```

---

### Step 5: Write Data and Verify Persistence

```bash
# Write data to the persistent volume
oc exec deploy/storage-demo -- sh -c 'echo "Hello from persistent storage!" > /data/test.txt'
oc exec deploy/storage-demo -- sh -c 'date >> /data/test.txt'

# Read the data
oc exec deploy/storage-demo -- cat /data/test.txt

# Delete the pod (Deployment will recreate it)
oc delete pod -l app=storage-demo

# Wait for the new pod
oc get pods -w

# Verify data persists in the new pod
oc exec deploy/storage-demo -- cat /data/test.txt
```

The data survives because it's stored on the PersistentVolume, not inside the container.

---

### Step 6: Inspect PV and PVC Details

```bash
# View PVC details
oc describe pvc my-data-pvc

# View the automatically created PV
oc get pv

# Describe the PV
oc describe pv $(oc get pvc my-data-pvc -o jsonpath='{.spec.volumeName}')
```

---

### Step 7: Expand a PVC (if supported)

```bash
# Check if StorageClass allows expansion
oc get storageclass -o jsonpath='{.items[*].allowVolumeExpansion}'

# If true, expand the PVC
oc patch pvc my-data-pvc -p '{"spec":{"resources":{"requests":{"storage":"2Gi"}}}}'

# Verify the new size
oc get pvc my-data-pvc
```

---

## Key Concepts

### Reclaim Policies

| Policy | Behavior |
|--------|----------|
| **Retain** | PV is kept after PVC deletion (data preserved, manual cleanup) |
| **Delete** | PV and underlying storage are deleted when PVC is deleted |
| **Recycle** | Deprecated — data is scrubbed and PV is made available again |

### Common Storage Backends

| Backend | Access Modes | Use Case |
|---------|--------------|----------|
| HostPath | RWO | Development/testing only |
| NFS | RWO, ROX, RWX | Shared storage, legacy apps |
| Ceph RBD | RWO | Block storage for databases |
| CephFS | RWO, RWX | Shared filesystem |
| AWS EBS | RWO | Cloud block storage |
| Azure Disk | RWO | Cloud block storage |

---

## Validation Checklist

- [ ] Created a PVC and verified it bound to a PV
- [ ] Mounted a PVC into a Pod
- [ ] Wrote data, deleted the Pod, and verified data persisted
- [ ] Inspected PV and PVC details
- [ ] Understand access modes and reclaim policies

---

## Clean Up

```bash
oc delete all -l app=storage-demo
oc delete pvc my-data-pvc
oc delete project lab-014-storage
```

---

## Next Lab

Proceed to [Lab 015: Networking — Service Types & Network Policies](../015-networking/README.md) to learn about advanced networking in OpenShift.
