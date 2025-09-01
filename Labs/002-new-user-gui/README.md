# Lab 002: Understanding Roles and Permissions (RBAC) - GUI Edition

## Overview

This lab covers Role-Based Access Control (RBAC) in OpenShift, including roles, role bindings, and permission management using **only the OpenShift Web Console**.

## Prerequisites

- Completed [Lab 001: Verify Cluster Health](../001-verify-cluster/README.md)
- OpenShift Local (CRC) running
- Access to the OpenShift Web Console (https://console-openshift-console.apps-crc.testing)
- Credentials for `developer` (developer/developer) and `kubeadmin`

---

## Lab Instructions

### Step 1: Understanding RBAC Components

RBAC stands for Role-Based Access Control. \
It controls who can perform which actions on what resources in OpenShift.

#### **Key Components:**

| Component              | Scope        | Description                                                 |
|------------------------|--------------|-------------------------------------------------------------|
| **Role**               | Namespace    | Defines permissions within a single project                 |
| **ClusterRole**        | Cluster-wide | Defines permissions across all projects                     |
| **RoleBinding**        | Namespace    | Grants Role permissions to users/groups in a project        |
| **ClusterRoleBinding** | Cluster-wide | Grants ClusterRole permissions to users/groups cluster-wide |

---

### Step 2: Understanding Permission Scopes

In OpenShift, permissions work at two levels: **cluster-wide** and **project-specific**.

#### Log in as Developer

1. Open the Web Console in your browser: `https://console-openshift-console.apps-crc.testing`
2. Log in with:
   - **Username**: `developer`
   - **Password**: `developer`

#### Check Your Current Context

1. Look at the top right corner to confirm you are logged in as `developer`.
2. Ensure you are in the **Developer** perspective (toggle directly below the logo in the top-left).
3. Click on the **Project** dropdown at the top and select `lab-000-setup` (if available) or any user project.

#### Test Cluster-Wide Permissions

Let's try to access cluster-level resources that developers typically don't have access to.

1. Switch to the **Administrator** perspective.
2. Navigate to **Administration** -> **Cluster Settings** or **Compute** -> **Nodes**.
3. **Observation**: You likely won't see these options in the navigation menu, or if you navigate to them directly, you will see an "Access denied" or "Restricted" message.
   - The `developer` user does not have `cluster-admin` rights, so they cannot view or manage nodes and cluster settings.

#### Test Project-Specific Permissions

1. Ensure you are in the `lab-000-setup` project (or your personal project).
2. Try to add content: Go to **Add** in the left menu.

3. **Observation**: You see options to "Import from Git", "Container Image", etc.
   - **Why?** You are an `admin` of this project (because you created it), so you can create resources like Deployments and Pods within it.

---

### Step 3: Create a Test Project

Let's create a new project to examine permissions from the start.

1. Click the **Project** dropdown at the top of the console.
2. Select **Create Project**.
3. Fill in the details:
   - **Name**: `rbac-demo`
   - **Display Name**: `RBAC Demo`
4. Click **Create**.

You will automatically be switched to this new project.

#### Check Permissions

1. Navigate to **User Management** -> **RoleBindings** (in Administrator perspective).

2. **Observation**: You can see the list of RoleBindings.
   - You should see an `admin` binding for your user (`developer`).
   - This confirms that as the creator, you have full control over this project.

#### Inspect Your RoleBinding

1. In the **RoleBindings** list, look for the row named `admin`.
2. **Observation**:
   - **Role ref**: `ClusterRole/admin` (The permissions granted)
   - **Subject**: `User/developer` (You)
3. Click on the `admin` RoleBinding name to view details.

   - This confirms you have the `admin` role *specifically* for the `rbac-demo` namespace.

---

### Step 4: Explore Built-in Roles

To explore all available roles, we need to look at Cluster Roles.

1. Navigate to **User Management** -> **Roles**.
2. **Note**: If you don't see "Roles" or cannot list them comfortably as `developer`, you might be restricted. Let's switch to `kubeadmin` for full visibility.

#### Log in as Kubeadmin

1. Click your username (top right) -> **Log out**.
2. Log in as `kubeadmin`.
   - **Password**: Run `cat ~/.crc/machines/crc/kubeadmin-password` in your terminal to retrieve it.

#### Examine Roles

1. Ensure you are in the **Administrator** perspective.
2. Navigate to **User Management** -> **Roles**.

3. Use the Filter by name box to search for: `view`.
4. Click on the `view` role.
   - Look at the **Rules** tab.

   - **Observation**: The verbs are mostly `get`, `list`, `watch`. This confirms it is read-only.

5. Go back and search for `edit`.
   - Click on the `edit` role.
   - **Observation**: Verbs include `create`, `delete`, `update`. This allows modifying resources.
   - **check**: Search for `RoleBinding` in the rules. You won't find it (or it won't have modify verbs). `edit` cannot manage permissions.

6. Go back and search for `admin`.
   - Click on the `admin` role.
   - **Observation**: It has permissions to manage `RoleBindings` and `Roles`. This is the key difference from `edit`.

---

### Step 5: Grant Permissions to Another User

We will now act as the cluster administrator to set up a scenario for our developer.

#### Create a Team Project

1. Click **Projects** (or Home -> Projects).
2. Click **Create Project**.
3. **Name**: `team-project`.
4. Click **Create**.

#### Grant 'Edit' Access to Developer

We want the `developer` user to be able to work in this project but not manage access for others.

1. Navigate to **User Management** -> **RoleBindings**.
2. Ensure the **Project** dropdown (top) is set to `team-project`.
3. Click **Create binding**.
4. Configure the binding:

   - **Binding type**: Cluster-wide role binding (default) or Namespace role binding. Usually, we select "Namespace role binding (RoleBinding)" but point to a "ClusterRole".
   - **Name**: `edit` (or `dev-edit-access`)
   - **Namespace**: `team-project`
   - **Role name**: Select `edit` from the list.
   - **Subject**:
     - **Subject kind**: `User`
     - **Subject name**: `developer`
5. Click **Create**.

You have now legally granted the `edit` role to the `developer` user for the `team-project` namespace.

---

### Step 6: Test Permissions as Developer

Let's verify what the developer can do.

1. **Log out** of `kubeadmin`.
2. **Log in** as `developer`.

#### Verify Access

1. Go to the **Project** list.
2. **Observation**: You should see `team-project` in your list.
3. Select `team-project`.

#### Test Capabilities

1. Switch to **Developer** perspective.
2. Go to **Add**.

3. **Observation**: You **can** see the options to add applications (e.g., "Import from Git"). This confirms you have `edit` access.

#### Test Limitations

1. Switch to **Administrator** perspective.
2. Navigate to **User Management** -> **RoleBindings**.
3. Try to click **Create binding**.
4. **Observation**: Depending on the exact console version, the button might be disabled, or if you click it and try to save, you will get an error ("Forbidden" or "Access denied").
   - **Why?** You have `edit` role, not `admin`. You cannot manage permissions.

---

### Step 7: Understanding Role vs RoleBinding

Let's create a custom Role and assign it. This requires Admin privileges.

1. **Log out** and log back in as **kubeadmin**.
2. Select `team-project`.

#### Create a Custom Role (Pod Reader)

1. Navigate to **User Management** -> **Roles**.
2. Click **Create Role**.
3. **YAML View** is often easier, but let's try the form if available, or paste the YAML.
   - **Name**: `pod-reader`
   - **Namespace**: `team-project`
   - **Rules**:
     - **APIGroups**: `""` (Core)
     - **Resources**: `pods`
     - **Verbs**: `get`, `list`, `watch`

   *(Or copy-paste this into the YAML editor):*
   ```yaml
   kind: Role
   apiVersion: rbac.authorization.k8s.io/v1
   metadata:
     name: pod-reader
     namespace: team-project
   rules:
   - apiGroups: [""]
     resources: ["pods"]
     verbs: ["get", "list", "watch"]
   ```
4. Click **Create**.

#### Assign the Role (Create RoleBinding)

1. Navigate to **User Management** -> **RoleBindings**.
2. Click **Create binding**.
3. **Name**: `read-pods`
4. **Namespace**: `team-project`
5. **Role name**: Select `pod-reader` (Note: verify it's a "Role", not "ClusterRole" if prompted, or just search by name).
6. **Subject**:
   - **Kind**: `User`
   - **Name**: `developer`
7. Click **Create**.

Now `developer` has two roles in this project: `edit` and `pod-reader`. Since `edit` is powerful, they won't notice `pod-reader`, but the binding exists.

---

### Step 8: Revoking Permissions

Let's remove the `edit` role so the developer becomes read-only (mostly).

1. Ensure you are logged in as **kubeadmin** in `team-project`.
2. Navigate to **User Management** -> **RoleBindings**.
3. Find the `edit` role binding used for `developer`.
4. Click the **Kebab menu** (three vertical dots) on the right side of the row.
5. Click **Delete RoleBinding**.

6. Confirm **Delete**.

#### Verify Impact

1. **Log out** and log back in as **developer**.
2. Go to `team-project`.
3. Switch to **Developer** perspective.
4. Go to **Add**.
5. **Observation**: You might see a simplified view or errors indicating you cannot create resources.
6. Go to **Administrator** perspective -> **Workloads** -> **Pods**.
7. **Observation**: You **CAN** see pods (if any existed).
   - **Why?** You still have the `pod-reader` role we created in Step 7.

---

### Step 9: Understanding ClusterRoleBindings

ClusterRoleBindings affect the whole cluster.

1. Log in as **kubeadmin**.
2. Navigate to **User Management** -> **RoleBindings**.
3. **Wait**, we need Cluster scope. In the left navigation, finding "ClusterRoleBindings" might require going to **Administration** -> **Cluster Settings** -> **Configuration** -> **RBAC** (location varies by version) OR simply:
   - Go to **User Management** -> **RoleBindings**.
   - Change the **Project** dropdown to **All Projects** or look for a separate **ClusterRoleBindings** tab if your version has one (usually it's mixed or under a distinct menu item in newer versions).
   - *Note*: In many OCP versions, ClusterRoleBindings are under **User Management** -> **ClusterRoleBindings** specifically.

4. Locate **ClusterRoleBindings**.
5. Search for `cluster-admin`.
6. Click on it.
7. **Observation**: You will see users or groups like `system:masters` or `kubeadmin` listed here. This explains why `kubeadmin` has full access everywhere.

---

## Best Practices (Summary)

- **Least Privilege**: Only give users the role they need (`view`, `edit`, `admin`).
- **Use Groups**: Bind roles to Groups (e.g., `developers-group`) rather than individual Users whenever possible. This makes onboarding/offboarding easier.
- **Audit**: Regularly check **User Management** -> **RoleBindings** in your projects to see who has access.

---

## Cleanup

1. Log in as **kubeadmin**.
2. Go to **Administration** -> **Projects** (or Home -> Projects).
3. Find `rbac-demo` and `team-project`.
4. Click the kebab menu for each and select **Delete Project**.
5. Confirm deletion by typing the project name.

---

## Next Steps

Continue to [Lab 003: Create New Project](../003-new-project/README.md).
