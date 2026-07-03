# Agenix — Automated Agent Identity Operator

**A Kubernetes operator that automates cryptographic identity provisioning for AI agents.**

Built at **Red Hat** | AI Agent Ops Team | Summer 2026

**Grace Smith** — [GitHub](https://github.com/gracesmith6504)

**[View the Demo Presentation & Slides](https://drive.google.com/drive/folders/1SewMkJJzBbne8LGlvamBNs2hVC87C3i6?usp=sharing)** — architecture walkthrough, live demo recordings, and technical deep dives

---

## What is Agenix?

In AI agent-to-agent systems, every workload needs a verifiable identity — but managing certificates manually doesn't scale. Agenix is a Kubernetes operator that solves this: you deploy an agent and create one custom resource, and the operator handles X.509 certificate issuance, SPIFFE ID generation, pod injection via webhook, rotation, and cleanup automatically.

The design uses composition over inheritance — the CRD references a target Deployment by name rather than embedding its spec, keeping identity concerns decoupled from workload configuration. Agenix is a simplified, educational take on production patterns from Red Hat's [Kagenti Operator](https://github.com/kagenti/kagenti).

> **This is my fork.** The upstream repo is [Bobbins228/Agenix](https://github.com/Bobbins228/Agenix). All PRs linked below were merged into upstream — I'm using this fork to showcase my contributions.

---

## My Contributions

I built the CRD, controller, and certificate provisioning pipeline — the core reconciliation path from "user creates a resource" to "agent pod has a verified cryptographic identity."

| PR | What I Built | Lines | Key Concepts |
|---|---|---|---|
| [#1](https://github.com/Bobbins228/Agenix/pull/1) | **CRD Design & Project Scaffolding** | +3,990 | Kubebuilder, OpenAPI v3 schema, `metav1.Time`, printcolumn markers, composition over inheritance |
| [#2](https://github.com/Bobbins228/Agenix/pull/2) | **CI Pipeline Fix** | +16 | GitHub Actions workflow path + go-version-file fix |
| [#5](https://github.com/Bobbins228/Agenix/pull/5) | **Controller Scaffolding** — CA init, RBAC, watches | +221 | Reconciliation loop, `For()`/`Owns()` watches, RBAC markers, status subresource |
| [#6](https://github.com/Bobbins228/Agenix/pull/6) | **Certificate Provisioning** in reconcile loop | +426 | X.509/ECDSA P-256, SPIFFE IDs, `CreateOrUpdate`, owner references, `RequeueAfter` at 2/3 TTL |
| [#13](https://github.com/Bobbins228/Agenix/pull/13) | **OpenShift Security Context** fix | +11 | `restricted-v2` SCC compliance, `runAsNonRoot`, `seccompProfile`, `ubi9-minimal` |
| — | **OpenShift Deployment & Validation** | — | Cross-arch build (ARM→AMD64), `quay.io` registry, ROSA HCP cluster, wrote [deployment guide](#openshift-deployment-guide) |

**Also:** Reviewed teammate's [PR #3](https://github.com/Bobbins228/Agenix/pull/3) — identified a SPIFFE ID validation bug before merge.

**Total: ~4,660 lines of Go across 5 merged PRs**, plus OpenShift deployment work and code review.

---

## Architecture

![Architecture Diagram](docs/images/architecture.png)

The operator follows the standard Kubernetes controller pattern:

1. Developer creates an `AgentIdentity` CR referencing a target `Deployment`
2. The **Controller** detects it via `For()` watch and enters the reconcile loop
3. Reads the target Deployment and its ServiceAccount
4. Generates a **SPIFFE ID** (`spiffe://<trustDomain>/ns/<namespace>/sa/<serviceAccount>`)
5. Issues an **X.509 certificate** (ECDSA P-256, signed by the in-process CA)
6. Stores cert material in a Kubernetes **Secret** with owner references
7. **Verifies** the certificate chain and SPIFFE ID → sets status to `Verified`
8. The **Mutating Webhook** intercepts pod creation and injects the TLS secret as a volume mount + environment variables
9. On deletion, a **Finalizer** cleans up the Secret, labels, and Deployment patches

---

## How the Reconcile Loop Works

![Reconcile Loop](docs/images/reconcile-loop.png)

Each step has error handling with descriptive status conditions. Certificate rotation requeues automatically at 2/3 of the TTL — so a 24-hour cert requeues after 16 hours. The controller uses `controllerutil.CreateOrUpdate` for idempotent Secret management, meaning it converges safely even if restarted mid-reconcile.

---

## Demos, Walkthroughs & Deep Dives

| Resource | What It Covers |
|---|---|
| [Demo Presentation Slides](https://drive.google.com/drive/folders/1SewMkJJzBbne8LGlvamBNs2hVC87C3i6?usp=sharing) | Architecture, design decisions, reconcile loop flowchart, team reflections |
| [Kind Cluster Demo](https://drive.google.com/file/d/1qkV0247kzi15x1ZPyuKX2SMp98Eabryg/view?usp=drive_link) | End-to-end operator demo on local Kind cluster |
| [OpenShift (ROSA) Demo](https://drive.google.com/file/d/15Spmyj1RzT_dq0Kgc-Fn5HHQbCdrvO13/view?usp=drive_link) | Operator running on production-like ROSA HCP cluster |
| [Full Demo Recording](https://drive.google.com/file/d/1vfJzEQCoi6YKvNo1Zxjbrz85DPu77eQi/view?usp=drive_link) | Complete team presentation with live demo |
| [Task 1: CRD Design Walkthrough](https://drive.google.com/file/d/1nydc-qVeaH3CI5O-fsYTxYFabdLthi2B/view?usp=drive_link) | Kubebuilder scaffolding, OpenAPI schema, composition vs inheritance, deep copy generation |
| [Task 4a: Controller Scaffolding Walkthrough](https://drive.google.com/file/d/1ZeDsMl2FH5o1ueqjvBqVUhAYACon6KOv/view?usp=drive_link) | Reconciliation loop, CA initialization, RBAC markers, `For()`/`Owns()` watches |
| [Task 4b: Certificate Provisioning Walkthrough](https://drive.google.com/file/d/1EILVZcwRd0m4iEfntr-kC6iv5172v1DD/view?usp=drive_link) | X.509 generation, SPIFFE IDs, `CreateOrUpdate`, owner refs, integration testing with envtest |
| [OpenShift Deployment Guide](https://drive.google.com/file/d/18v2-GVL9Nn0o7dcLWYSMxJozBzVoi1om/view?usp=drive_link) | Cross-arch builds, SCC compliance, ROSA HCP deployment, validation steps |
| [Learning Exercises](https://drive.google.com/file/d/1G5gEpDMvML3V0Hnw-SGQ4xkUskOrhDAq/view?usp=drive_link) | 15 pages of intentional breakage experiments across all tasks — CRDs, certs, webhooks, finalizers |

---

## What I Learned

Beyond the code, I intentionally broke things to understand how they work. Highlights from 15 pages of learning exercises across all tasks:

- **Deleting a CRD cascades to ALL custom resources of that type** — they cannot be recovered. The CRD is the definition; without it, Kubernetes can't keep any instances.
- **Chain validation fails when a leaf cert is self-signed** — the CA proves the identity is legitimate. Without chain validation, any agent could forge its own identity.
- **Owner references vs finalizers serve different purposes** — owner refs handle same-namespace garbage collection automatically; finalizers are needed when cleanup spans namespaces or involves external resources. You need both.
- **Manually removing a finalizer is dangerous** — it tells Kubernetes "cleanup is done" when the cleanup logic hasn't actually run, leaving orphaned resources behind.
- **`For()` vs `Owns()` watches** — `For()` triggers reconcile when the primary resource changes; `Owns()` triggers reconcile of the *owner* when a child resource (like a Secret) changes. Getting this wrong means the controller misses updates.

---

## Technologies

Go, Kubernetes, Kubebuilder, controller-runtime, X.509 / SPIFFE, ECDSA P-256, Ginkgo / Gomega, envtest, GitHub Actions, OpenShift / ROSA HCP, Kustomize, Podman, cert-manager

---

## How I Worked

All contributions followed the [Kagenti project's contributing guidelines](https://github.com/kagenti/kagenti/blob/main/CONTRIBUTING.md) and [development guide](https://github.com/kagenti/kagenti/blob/main/docs/dev-guide.md):

- **Fork-and-branch workflow** — worked from a personal fork, rebased from upstream before each PR
- **DCO sign-off** on every commit (Developer Certificate of Origin)
- **Conventional commits** — prefixed with `feat:`, `fix:`, `docs:`, `test:` for clear git history
- **Pre-commit linting** — ran `make lint` before every push
- **PR descriptions** included problem context, solution explanation, and how testing was performed
- **Code review** — reviewed teammates' PRs and responded to review feedback on my own

---

## About the Project

Agenix was built as a team intern project at Red Hat by three interns on the AI Agent Ops team. The upstream repo is [Bobbins228/Agenix](https://github.com/Bobbins228/Agenix). I built the CRD, controller, and certificate provisioning (Tasks 1, 4a, 4b), plus OpenShift deployment. Other team members built the CA, webhook, verification, SPIFFE utilities, and finalizer/lifecycle management.

For the full project README (setup instructions, API reference, architecture details), see the [upstream repo](https://github.com/Bobbins228/Agenix).
