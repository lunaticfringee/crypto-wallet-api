# Runbook: High Error Rate Alert

**Alert:** `High Error Rate` (fires when error rate > 10% for 1 minute)
**Dashboard:** Crypto Wallet API - Overview → Error Rate (%) panel

## First steps

1. Check which endpoint is affected — Grafana's Error Rate panel breaks down by handler
2. Check `wallet-service` logs for the specific error:
docker logs crypto-wallet-api-wallet-service-1 --tail 50

3. Check Jaeger for the failing trace (Service: `wallet-service`, filter by error) — look at `span.kind` and `otel.status_description` for the precise failure

## Known causes (from past incidents)

- **CoinGecko rate limit (429)** — `/price/{coin}` returns `503 price service temporarily unavailable`. Self-resolves once CoinGecko's rate limit window passes; no action needed beyond monitoring. See resilience pattern in `wallet-service/main.py` (`fetch_price_from_coingecko`).
- **compliance-service unreachable** — `/wallet/{address}/balance` returns `503 compliance check unavailable, cannot proceed`. Check:

docker compose ps compliance-service

If stopped/crashed, restart:

docker compose start compliance-service

See full incident writeup: [`docs/incidents/2026-08-02-compliance-service-outage.md`](../incidents/2026-08-02-compliance-service-outage.md)

## Escalation

No real on-call/paging is configured for this local project (placeholder contact point only). In production, this alert would route to [on-call rotation / Slack channel — TBD].