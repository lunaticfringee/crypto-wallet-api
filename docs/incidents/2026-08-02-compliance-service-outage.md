# Incident: Compliance Service Outage — wallet-service Balance Check Failure

**Date:** August 2, 2026
**Severity:** High (single endpoint fully unavailable)
**Status:** Resolved
**Author:** Sai

---

## Summary

A simulated dependency outage was performed by stopping the `compliance-service` container, which `wallet-service`'s `/wallet/{address}/balance` endpoint depends on for a mandatory pre-check. The endpoint had no timeout or exception handling around this dependency, resulting in an unhandled exception and a generic `500 Internal Server Error` for all requests during the outage.

## Timeline

| Time | Event |
|---|---|
| 23:16:19 – 23:16:25 | `compliance-service` container stopped; balance check requests begin failing |
| 23:16:19 – 23:20:24 | Multiple failed requests observed, ~1.9s response time, `500 Internal Server Error` |
| — | Investigation: Grafana Error Rate panel confirmed spike; `wallet-service` logs showed full unhandled traceback; Jaeger confirmed the same root cause at the span level |
| — | Fix implemented: timeout + fail-closed exception handling added to `get_balance` |
| — | `compliance-service` restarted; fix verified under both failure and recovery conditions |

## Impact

The `/wallet/{address}/balance` endpoint was fully unavailable for the duration of the `compliance-service` outage (approximately 4 minutes, based on trace timestamps 11:16pm–11:20pm). All requests to this endpoint during the outage returned `500 Internal Server Error` with no informative error message. Other endpoints (`/health`, `/price/{coin}`) were unaffected, since they have no dependency on `compliance-service`. In a production context, this would mean users attempting to check wallet balances during the outage would receive no usable feedback about why the request failed, and would have no way to distinguish this from an unrelated system-wide failure.

## Detection

The outage was deliberately triggered as part of a fault-injection exercise (not detected via a real alert notification — a placeholder alerting contact point was configured, but no real notification channel was wired up). It was identified and confirmed via three independent signals:

1. **Grafana** — Error Rate panel showed a spike to ~60% correlating with the outage window
2. **Structured logs** (`docker logs`) — full Python traceback pinpointing the exact failing line (`main.py`, line 50, `requests.get()` call to `compliance-service`)
3. **Jaeger distributed tracing** — the failed span independently captured the identical exception message (`otel.status_code: ERROR`, full `ConnectionError`/`NameResolutionError` text) as a span attribute, with `span.kind: client`, confirming the failure occurred at the network call to `compliance-service` and never reached it

## Root Cause

`wallet-service`'s `get_balance` function made an unprotected `requests.get()` call to `compliance-service` with no timeout and no exception handling. When `compliance-service` was stopped, Docker Compose removed its DNS entry from the internal Docker network, causing `requests` to raise an unhandled `ConnectionError` (specifically a `NameResolutionError`) when attempting to resolve the hostname `compliance-service`. This propagated as an unhandled exception, crashing the request with a generic `500 Internal Server Error` rather than a controlled, informative failure.

## Resolution

Added explicit timeout (`timeout=3`) and exception handling (`try`/`except requests.exceptions.RequestException`) around the compliance-service call. On failure, the endpoint now returns a clean `503 Service Unavailable` with the message `"compliance check unavailable, cannot proceed"`, and logs a structured error entry with the affected address.

**Design decision — fail closed, not fail open:** unlike the existing CoinGecko integration (which retries and eventually fails with a generic price-service-unavailable message), the compliance check was deliberately designed to **fail closed** — if the compliance service cannot be reached, the balance check is refused entirely rather than silently bypassed. This reflects the regulated nature of compliance/risk checks in financial infrastructure, where silently skipping a compliance check during a dependency outage would be a more serious risk than temporary unavailability.

Verified under both failure (consistent, clean `503` responses) and recovery (`compliance-service` restarted, normal `200` response confirmed, response time returned to baseline ~0.3s).

## Action Items

- [ ] Apply the same timeout/exception-handling pattern proactively to any future outbound service calls, rather than only after discovering gaps reactively
- [ ] Wire up a real alerting notification channel (Slack/email) rather than the current placeholder contact point, so future incidents are detected via alert rather than manual investigation
- [ ] Consider adding a circuit breaker pattern (beyond simple timeout/exception handling) if `compliance-service` call volume grows, to avoid repeated slow-timeout attempts during an extended outage
- [ ] Evaluate whether `compliance-service` itself needs redundancy/multiple replicas, given `wallet-service`'s hard dependency on it