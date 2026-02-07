# End-to-End AKS GitOps Platform (Terraform + ArgoCD)

This project implements a **production-style GitOps platform on Azure Kubernetes Service (AKS)** using **Terraform** for infrastructure provisioning and **ArgoCD** for continuous deployment.

The goal of this project is **not** to build application code, but to design, deploy, and operate a **multi-environment Kubernetes platform** that mirrors how real cloud teams manage infrastructure and deployments in production.

---

## High-Level Architecture

<img width="1536" height="1024" alt="Terraform pipeline with AKS deployment" src="https://github.com/user-attachments/assets/2e12fcd7-e060-499d-a713-251eebed010e" />




At a high level, the system is composed of four major layers:

1. **Infrastructure Layer (Terraform + Azure)**
2. **Platform Layer (AKS + ArgoCD)**
3. **Application Layer (3-tier app via GitOps)**
4. **Secrets & Configuration Layer (Azure Key Vault + CSI Driver)**

All environments (dev, test, prod) follow the **same architectural pattern**, with differences only in scale, sizing, and intended usage.

---

## Infrastructure Layer (Terraform)

Terraform is responsible for **creating and owning all Azure infrastructure**, including:

- Azure Resource Groups
- Azure Kubernetes Service (AKS) clusters
- Networking (Azure CNI, subnets, network policies)
- Managed identities
- Azure Key Vault
- Access policies required for Key Vault integration
- Installation of platform components (ArgoCD)

Each environment (`dev`, `test`, `prod`) is implemented as a **separate Terraform root module**, which provides:

- Complete isolation between environments
- Independent Terraform state
- Independent lifecycle (one environment can be destroyed without affecting others)

### Why separate Terraform roots per environment?

This mirrors real-world practice:

- **dev** can be rebuilt frequently
- **test** remains stable for integration testing
- **prod** is protected and changed carefully

---

## Platform Layer (AKS + ArgoCD)

### AKS

Each environment deploys its own AKS cluster.  
The cluster provides:

- Container orchestration
- Pod scheduling
- Service discovery
- Autoscaling
- Network isolation

AKS is treated as a **platform**, not as a place to manually deploy workloads.

### ArgoCD

ArgoCD is installed into each cluster using Terraform (via the Helm provider).

ArgoCD’s role is critical:

- It continuously watches a **Git repository** (GitOps repo)
- It treats Git as the **single source of truth**
- It applies Kubernetes manifests automatically
- It detects drift and reports health/sync status

Once ArgoCD is running, **Terraform does not deploy application resources directly**.  
Terraform deploys the *platform*, ArgoCD deploys the *applications*.

This separation is intentional.

---

## Application Layer (GitOps)

The deployed workload is a **3-tier web application**, composed of:

### Frontend
- React-based application
- Exposed internally via a Kubernetes Service
- Accessed via port-forwarding or ingress (depending on environment)
- Communicates with the backend using Kubernetes DNS

### Backend
- Node.js API
- Exposes a `/health` endpoint used by Kubernetes probes
- Reads database configuration from ConfigMaps and Secrets
- Communicates with PostgreSQL using internal service DNS

### Database (PostgreSQL)
- Runs as a Stateful component
- Uses a PersistentVolumeClaim for data persistence
- Credentials are **not hardcoded**
- Credentials are injected dynamically from Azure Key Vault

### Important Design Choice: Images

This project **intentionally does not build container images**.

Instead, it uses **prebuilt, public images** provided by the tutorial author:

- `itsbaivab/frontend`
- `itsbaivab/backend`
- `postgres:15`

This was a deliberate choice to keep the project focused on:
- Infrastructure
- GitOps
- Kubernetes operations
- Cloud security

Not application development.

---

## Secrets & Configuration (Azure Key Vault + CSI Driver)

One of the most important aspects of this project is **externalized secrets management**.

### Why Key Vault?

- No secrets stored in Git
- No secrets baked into images
- Centralized secret rotation
- Azure-native identity integration

### How secrets flow through the system

1. Terraform creates an Azure Key Vault
2. Terraform enables the **Key Vault Secrets Provider add-on** in AKS
3. A managed identity is created specifically for the CSI driver
4. Access policies are granted to that identity
5. Kubernetes `SecretProviderClass` objects reference Key Vault secrets
6. Secrets are mounted into pods and optionally synced into Kubernetes Secrets

### Critical Identity Decision

A major issue encountered was **using the wrong managed identity**.

- ❌ Kubelet identity → results in `403 Forbidden`
- ✅ Key Vault Secrets Provider identity → correct and required

This distinction is subtle but critical and reflects a real-world pitfall.

---

## Multi-Environment Strategy (dev / test / prod)

### dev Environment

**Purpose**
- Rapid experimentation
- Debugging
- Learning and iteration

**Characteristics**
- Smallest node sizes
- Lowest cost
- Can be destroyed and recreated frequently
- First environment to receive changes

**Role**
- Prove infrastructure correctness
- Validate GitOps flow
- Catch configuration mistakes early

---

### test Environment

**Purpose**
- Integration testing
- Pre-production validation

**Characteristics**
- Larger node sizes than dev
- More replicas
- More realistic scaling behavior

**Role**
- Verify that changes behave correctly in a more production-like setup
- Validate that dev-tested changes are safe to promote

---

### prod Environment

**Purpose**
- Production-grade deployment

**Characteristics**
- Largest VM sizes
- Higher replica counts
- Autoscaling tuned for reliability
- Most expensive environment

**Role**
- Represent real-world operational constraints
- Demonstrate how the same architecture scales safely

---

## Major Problems Encountered (and What They Taught)

### 1. Terraform Backend Hanging (Managed Identity Issue)

**Problem**
Terraform backend initialization tried to authenticate via Managed Identity from a local machine, resulting in requests to:
http://169.254.169.254/metadata/identity/oauth2/token


**Root Cause**
Managed Identity only works when Terraform runs on an Azure resource that has an identity attached.

**Resolution**
- Understood that MSI is environment-specific
- Used CLI / Service Principal auth locally
- Planned for MSI usage only when running Terraform from Azure DevOps agents

**Lesson**
Authentication mechanisms must match the execution environment.

---

### 2. Script Permission Failures (`Permission denied`)

**Problem**
Terraform `local-exec` failed to run scripts.

**Root Cause**
Shell scripts were not marked executable.

**Resolution**
- Fixed file permissions
- Reinforced understanding of Unix execution model

**Lesson**
Infrastructure automation still obeys OS-level rules.

---

## Why This Project Matters

This project demonstrates:

- Real GitOps workflows
- Proper separation of concerns
- Secure secret management
- Multi-environment infrastructure design
- Cloud-native identity handling
- Debugging of non-obvious, production-grade issues

It is intentionally **infrastructure-first**, not application-first.

