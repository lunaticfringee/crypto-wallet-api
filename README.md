# crypto-wallet-api

A production-pattern crypto wallet platform built as a hands-on SRE/DevOps/Platform Engineering project — covering the full lifecycle from application code through observability, container orchestration, cloud infrastructure, and CI/CD.

This isn't a tutorial follow-along. Every piece was built incrementally, and every real failure encountered along the way — AWS networking gaps, IAM permission boundaries, OIDC trust configuration, Kubernetes resource limits — was diagnosed and fixed from first principles. Those incidents are documented inline and in [RUNBOOK.md](./RUNBOOK.md).

## What this project demonstrates

- **Application design**: FastAPI microservices with fail-closed security patterns, retry/backoff on external dependencies, structured logging
- **Full observability stack**: metrics, logs, and distributed traces, correlated via trace ID injection
- **Container orchestration**: both Kubernetes (kind) and AWS ECS Fargate, with real deployment strategies (Rolling, Blue-Green, Canary) and RBAC
- **Infrastructure as Code**: modular Terraform with environment separation, remote state, and native S3 locking
- **CI/CD**: GitHub Actions with OIDC federation (zero stored credentials), automated build → push → deploy pipelines
- **Real incident response**: nine documented incidents, each diagnosed with root cause analysis, not just patched

## Architecture

See [ARCHITECTURE.md](./ARCHITECTURE.md) for the full diagram and component breakdown.

**High-level flow:**

Internet → ALB (public subnet) → ECS Fargate tasks (private subnet) → wallet-service / compliance-service
↓
Prometheus / Grafana / Jaeger (observability)

## Services

### wallet-service
- `/health` — liveness/readiness endpoint
- `/price/{coin}` — CoinGecko price lookup with exponential backoff retry
- `/balance/{address}` — Ethereum balance lookup, **gated behind a fail-closed compliance check** (returns 503 if compliance-service is unavailable, rather than silently allowing an unchecked transaction)

### compliance-service
- `/health` — liveness/readiness endpoint
- `/check/{address}` — checks an address against a blocklist

Both services emit structured JSON logs (with trace ID injection), Prometheus metrics, and OpenTelemetry traces.

## Tech stack

| Layer | Tools |
|---|---|
| Application | Python, FastAPI, Uvicorn |
| Containers | Docker, Docker Compose |
| Orchestration | Kubernetes (kind), AWS ECS Fargate |
| Observability | Prometheus, Grafana, Jaeger, OpenTelemetry, CloudWatch |
| IaC | Terraform (modular, environment-split) |
| Cloud | AWS (VPC, ECS, ECR, ALB, IAM, S3, VPC Endpoints) |
| CI/CD | GitHub Actions, OIDC federation |

## Repository structure

crypto-wallet-api/
├── wallet-service/ # FastAPI app + observability instrumentation
├── compliance-service/ # FastAPI app + observability instrumentation
├── k8s/ # Kubernetes manifests (Deployments, RBAC, deployment strategies)
├── monitoring/ # Grafana dashboards + alert rules, as code
├── terraform/
│ ├── bootstrap/ # One-time account-level infra: state bucket, OIDC provider, CI/CD IAM role
│ ├── modules/ # Reusable modules: vpc, security-groups, ecr, iam, ecs, alb
│ └── environments/dev/ # Environment composition, calls modules with env-specific values
├── .github/workflows/ # CI/CD pipelines (per-service deploy, Terraform plan-on-PR)
├── docs/incidents/ # Real incident RCA write-ups
└── docs/runbooks/ # Operational runbooks

## Running locally

```bash
docker compose up -d --build
curl http://localhost:8000/health   # wallet-service
curl http://localhost:8001/health   # compliance-service
```

Grafana: `http://localhost:3000` · Prometheus: `http://localhost:9090` · Jaeger: `http://localhost:16686`

## Deploying to AWS

```bash
cd terraform/bootstrap && terraform init && terraform apply   # one-time: state bucket, OIDC, CI/CD role
cd ../environments/dev && terraform init && terraform apply    # full infrastructure
```

Application deploys happen automatically via GitHub Actions on push to `main` (path-scoped per service). Infrastructure changes go through `terraform plan` automatically on PR (posted as a PR comment); `apply` is a deliberate, manual step — infrastructure changes carry a different risk profile than application deploys and are treated accordingly.

## Key design decisions

- **Fail-closed, not fail-open**: if compliance-service is unreachable, wallet-service refuses the balance check rather than allowing it through unchecked.
- **Private subnets for compute, VPC Endpoints instead of a NAT Gateway**: ECS tasks have no public IP; outbound AWS API access (ECR, CloudWatch, S3) goes through VPC Interface/Gateway Endpoints, avoiding NAT Gateway's per-hour cost for our narrow, AWS-only outbound needs.
- **Immutable ECR tags + Git-SHA tagging**: every image is traceable to the exact commit that built it; nothing is ever overwritten in place.
- **OIDC over static credentials**: GitHub Actions authenticates to AWS via short-lived, per-run federated tokens — no long-lived access keys stored anywhere.
- **Terraform apply is manual, plan is automated**: infrastructure changes are reviewable (via an automated PR comment showing the diff) but not auto-applied, given their higher blast radius compared to application deploys.

## Incident log

Nine real incidents were diagnosed and resolved during this project's development — not scripted, not anticipated in advance. Full write-ups: [RUNBOOK.md](./RUNBOOK.md).

1. Unpinned `:latest` image tag caused a silent Jaeger UI regression
2. Kubernetes pod OOM-killed under memory pressure (exit code 137)
3. ECS tasks in a private subnet couldn't pull from ECR (no internet route) — fixed with VPC Endpoints
4. ALB provisioning failed — AWS requires multi-AZ subnets
5. ALB provisioning failed — VPC had no Internet Gateway
6. GitHub Actions OIDC trust rejected — subject claim format included immutable IDs not covered by the original policy pattern
7. Terraform state locking failed in CI — read-only IAM policy didn't cover the S3 write needed for lock acquisition
8. A real AWS access key was pasted into a chat session — rotated live via CLI using a create-before-revoke pattern
9. Infrastructure changes applied directly to AWS were lost from `main` when an unmerged feature branch was deleted — restored and root-caused

## License

Personal portfolio / learning project.