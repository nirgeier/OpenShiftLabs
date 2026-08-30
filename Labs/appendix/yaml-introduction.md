# Appendix C: YAML Introduction

> Maps to the video course *"APPENDIX C – YAML Introduction"*.
> Every OpenShift object is defined in YAML. Ten minutes here will make every lab
> easier to read.

## What is YAML?

YAML ("YAML Ain't Markup Language") is a human-readable format for structured
data. Kubernetes and OpenShift use it to describe the **desired state** of every
object - Pods, Deployments, Services, Routes, and more.

## The three building blocks

### 1. Key–value pairs

```yaml
name: my-app
replicas: 3
enabled: true
```

- A colon **and a space** separate key from value.
- Values can be strings, numbers, or booleans.

### 2. Lists (sequences)

Each item begins with a dash `-`:

```yaml
fruits:
  - apple
  - banana
  - cherry
```

### 3. Dictionaries (maps / nested objects)

Nesting is expressed purely by **indentation** (spaces, never tabs):

```yaml
metadata:
  name: my-app
  labels:
    app: web
    tier: frontend
```

## Indentation is everything

- Use **spaces only** - tabs are invalid and will break parsing.
- Two spaces per level is the convention.
- Items at the same indentation level belong to the same parent.

```yaml
spec:
  containers:        # a list of containers
  - name: web        # first (and only) list item
    image: nginx     # a property of that item
    ports:
    - containerPort: 80
```

## A complete, annotated Kubernetes object

```yaml
apiVersion: apps/v1        # which API group/version defines this object
kind: Deployment           # the type of object
metadata:                  # identifying data
  name: web
  labels:
    app: web
spec:                      # the desired state
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:                # the Pod blueprint
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: web
        image: nginx:alpine
        ports:
        - containerPort: 80
```

Every OpenShift manifest follows this same top-level shape:
`apiVersion` + `kind` + `metadata` + `spec`.

## Handy extras

**Comments** start with `#`:

```yaml
replicas: 3   # scale to three pods
```

**Multi-document files** separate objects with `---` (used throughout these labs):

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
```

**Multi-line strings** with the block scalar `|` (keeps newlines):

```yaml
args:
- |
  nginx -g 'daemon off;' &
  sleep 10
```

## Validate before you apply

```bash
# Dry-run: check the YAML without creating anything
oc apply -f manifest.yaml --dry-run=client

# See the full schema and field docs for any object
oc explain deployment.spec.template.spec.containers
```

## Common mistakes

| Symptom | Cause |
|---|---|
| `error converting YAML to JSON` | Tabs used instead of spaces |
| `mapping values are not allowed` | Missing space after a colon |
| Fields silently ignored | Wrong indentation level |
| `unknown field` | Typo in a key name - check with `oc explain` |

## Next

You now have everything you need to read and edit the manifests in every lab.
Start applying them in [Lab 008: Deployments](../008-deploying/README.md).
