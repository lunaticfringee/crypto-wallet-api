# Crypto Wallet API — Hands-On SRE/DevOps Project

A multi-service crypto data platform built to demonstrate production-grade infrastructure and SRE practices: observability (metrics, logs, traces), resilience patterns, alerting, and incident response — built hands-on as interview/portfolio preparation.

## What it does

- **wallet-service** — exposes crypto price data (via CoinGecko) and Ethereum wallet balance lookups (via Infura), gated behind a compliance check
- **compliance-service** — a mock AML/risk-check service, called by wallet-service before returning any balance

The application logic is intentionally simple — the focus of this project is the surrounding infrastructure and operational patterns.

## Stack

- **App:** Python, FastAPI
- **Observability:** Prometheus, Grafana, OpenTelemetry, Jaeger
- **Blockchain (local test nodes):** Ganache (Ethereum), Bitcoin Core (regtest)
- **Container-level monitoring:** cAdvisor
- **Orchestration (local dev):** Docker Compose

## Running locally

```bash
docker compose up -d
```

Then visit:
- Wallet API: http://127.0.0.1:8000/docs
- Compliance API: http://127.0.0.1:8001/docs
- Grafana: http://127.0.0.1:3000
- Prometheus: http://127.0.0.1:9090
- Jaeger: http://127.0.0.1:16686

Copy `.env.example` to `.env` in each service folder and fill in real values (Infura project ID) before running.

## Documentation

- [Incident reports](docs/incidents/)
- Runbooks: coming soon

## Status

Actively in progress — Kubernetes deployment, Terraform, CI/CD, and AWS deployment (ECS) are the next phases.