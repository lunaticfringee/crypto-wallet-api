# Runbook & Incident Log

This document records real incidents encountered while building and operating this project — each with the actual symptom, root cause, fix, and the general lesson. None of these were staged; all were genuine failures hit during real development and deployment.

---

## 1. Unpinned image tag caused a silent regression

**Symptom:** Jaeger UI behaved unexpectedly after a routine `docker compose up`.

**Root cause:** the Jaeger image was referenced as `:latest`. A new upstream release changed behavior without any corresponding change in our own code or commit history.

**Fix:** pinned every image in `docker-compose.yml` to an explicit version (e.g., `jaegertracing/all-in-one:1.60`). One documented exception (Bitcoin Core, due to an inconsistent maintainer tagging scheme) is explicitly called out as such.

**Lesson:** unpinned tags mean your environment can change without a corresponding code change — this became a standing rule applied to every subsequent image and, later, every ECR repository (`image_tag_mutability = "IMMUTABLE"`).

---

## 2. Kubernetes pod OOM-killed (exit code 137)

**Symptom:** pods repeatedly restarting; `kubectl get pods` showed `CrashLoopBackOff`.

**Diagnosis:** `kubectl describe pod <name>` showed `Last State: Terminated, Reason: OOMKilled, Exit Code: 137`. `free -h` on the host confirmed genuine memory pressure (single-digit MB free).

**Fix:** reduced replica count to match available memory on the constrained local dev environment (8GB RAM, WSL2 capped at 4GB).

**Lesson:** exit code 137 = SIGKILL, almost always from an OOM condition on constrained hosts or containers without adequate memory limits/requests.

---

## 3. ECS tasks in a private subnet couldn't pull images from ECR

**Symptom:** ECS Service showed `Running: 0, Desired: 1` indefinitely. `aws ecs describe-tasks` showed:

ResourceInitializationError: unable to pull secrets or registry auth: ...
dial tcp 3.112.64.17:443: i/o timeout

**Root cause:** ECS tasks were correctly placed in a private subnet (no public IP, per design) — but private subnets have no outbound internet route by default, and ECR's authentication endpoint is reached over the internet unless a private path exists.

**Fix:** added VPC Interface Endpoints for `ecr.api`, `ecr.dkr`, and `logs`, plus a Gateway Endpoint for `s3` (ECR stores image layers in S3 internally). Chose Endpoints over a NAT Gateway — no per-hour NAT charge, and traffic never leaves AWS's network.

**Lesson:** a private subnet's *security* correctness (no public IP) doesn't automatically include *connectivity* for legitimate AWS API calls — these are separate concerns requiring separate configuration.

---

## 4. ALB provisioning failed — single-AZ subnet

**Symptom:**

ValidationError: At least two subnets in two different Availability Zones must be specified
\
**Root cause:** the original VPC design had only one public subnet. This worked for every earlier resource, but AWS enforces a genuine multi-AZ requirement specifically for Application Load Balancers, for high availability.

**Fix:** added a second public subnet in a different AZ (`ap-northeast-1c`), passed both to the ALB module.

**Lesson:** some architectural requirements only surface when you reach the specific resource that enforces them — this doesn't mean the earlier design was "wrong," just incomplete for what came next.

---

## 5. ALB provisioning failed — no Internet Gateway

**Symptom:**

InvalidSubnet: VPC vpc-xxx has no internet gateway

**Root cause:** the VPC never had an Internet Gateway or route table sending traffic to it. `map_public_ip_on_launch = true` alone (set on the public subnets) only assigns public IPs — it does not by itself create an internet route.

**Fix:** added `aws_internet_gateway`, a public route table with a `0.0.0.0/0` route to the gateway, and explicit route table associations for both public subnets.

**Lesson:** true "public" connectivity requires both a public IP assignment **and** a route to an Internet Gateway — these are two independent, both-required pieces, a common point of confusion.

---

## 6. GitHub Actions OIDC authentication rejected

**Symptom:**

Error: Could not assume role with OIDC: Not authorized to perform sts:AssumeRoleWithWebIdentity

— despite trust policy and OIDC provider both appearing correctly configured.

**Diagnosis:** added a temporary workflow step to decode and print the actual JWT claims GitHub was sending. Revealed:

"sub": "repo:lunaticfringee@34905595/crypto-wallet-api@1326101735:ref:refs/heads/main"

— not the plain `repo:owner/repo:*` format most documentation examples show. GitHub now embeds immutable numeric account/repo IDs in the subject claim.

**Fix:** updated the IAM trust policy's `StringLike` condition to `repo:lunaticfringee@*/crypto-wallet-api@*:*`, matching the real format.

**Lesson:** when authentication fails and configuration looks correct on paper, decode and inspect the actual token/claims being presented rather than trusting documentation or assumptions about format.

---

## 7. Terraform state lock acquisition failed in CI

**Symptom:**

AccessDenied: ... is not authorized to perform: s3:PutObject on resource:
".../dev/terraform.tfstate.tflock"

**Root cause:** the GitHub Actions IAM role had `ReadOnlyAccess` for `terraform plan`, but native S3 state locking requires a genuine write (`PutObject`) to create the lock file object — a write operation not covered by a read-only policy.

**Fix:** added a narrowly-scoped policy granting `GetObject`/`PutObject`/`DeleteObject` on the state bucket's objects, and `ListBucket` on the bucket itself (a separate resource-level permission, per AWS's API design).

**Lesson:** "read-only" at the Terraform command level (`plan`) still involves genuine write operations at the infrastructure level, specifically for locking — these are separate permission concerns.

---

## 8. Real AWS credential exposure

**Symptom:** an AWS Access Key ID and Secret Access Key were pasted directly into a chat session during `aws configure` setup.

**Response:** treated as a genuine security incident regardless of the exposure being "private." Rotated live via CLI using a create-before-revoke pattern:
1. `aws iam create-access-key` — new key created first, to avoid lockout
2. Verified the new key worked (`aws sts get-caller-identity`)
3. `aws iam update-access-key --status Inactive` on the old key
4. Verified inactivation
5. `aws iam delete-access-key` — old key permanently removed

**Lesson:** this is the same pattern real organizations use for both manual and automated (Secrets Manager + Lambda) credential rotation — create the replacement before revoking the original, verify at each step, never assume "private" means "safe to leave live."

---

## 9. Infrastructure changes lost via deleted branch

**Symptom:** `terraform/bootstrap/main.tf` on `main` was missing two IAM policy resources that were confirmed live and working in AWS.

**Root cause:** those resources were applied directly to AWS while working on a feature branch (`test/terraform-ci`), but only ever committed on that branch. After closing the PR without merging and deleting the branch (both locally and on the remote), those commits — and the only record of the change in version control — were gone. The actual AWS resources remained live throughout, since `apply` had already run; only the source-of-truth code was lost.

**Fix:** re-added the resources to `main`'s `terraform/bootstrap/main.tf`; `terraform plan` confirmed they already existed in state (no-op restoration, not a new creation).

**Lesson:** apply infrastructure changes and commit them to the shared branch in the same breath — don't let `terraform apply` and the corresponding commit drift apart, especially on a branch that might later be deleted.

---

## 11. EKS pod scheduling failure — max-pods-per-node limit, not CPU/memory

**Symptom:** after installing ArgoCD via Helm, two of its pods (`argocd-application-controller`, `argocd-notifications-controller`) stayed `Pending` indefinitely, despite the node showing substantial free CPU (1930m) and memory (1466Mi).

**Diagnosis:** `kubectl describe pod` on the pending pods showed:

0/1 nodes are available: 1 Too many pods.

`kubectl describe node` confirmed the node's allocatable pod count was capped at 11 — already reached by system pods (`kube-proxy`, `coredns`, `aws-node`) plus the running application and ArgoCD pods.

**Root cause:** EKS's max-pods-per-node limit is derived from the VPC CNI's IP allocation — each pod requires a real VPC IP, and the ceiling is a function of the instance type's number of ENIs × IPs-per-ENI, not CPU or memory. `t3.small` (chosen for Free Tier eligibility) has a low ENI/IP allocation, producing a hard ceiling of 11 pods regardless of available compute.

**Fix:** switched the node group's instance type to `m7i-flex.large` — still Free Tier eligible, but with more ENIs and IPs-per-ENI, raising the effective pod ceiling. Required a node group replacement (`instance_types` forces replacement in Terraform), which evicted and rescheduled all existing pods — genuinely fine for a dev cluster, but a real operational concern for production node type changes.

**Lesson:** pod capacity planning on EKS is a distinct concern from compute sizing — ample CPU/memory headroom does not guarantee scheduling succeeds if the node has hit its IP-derived pod ceiling. Worth checking `kubectl describe node`'s allocatable `pods:` value specifically when diagnosing "Pending with no resource pressure" symptoms.

---

## Operational notes

- **Cost discipline**: Fargate tasks, the ALB, and VPC Interface Endpoints all carry real hourly costs. IAM, small S3 objects, and empty/near-empty ECR repositories are effectively free. Standing practice: `terraform destroy` (or scale services to 0) at the end of any active work session; keep only the near-zero-cost bootstrap layer (state bucket, OIDC provider, IAM roles) running continuously, since CI/CD depends on it.
- **ECR lifecycle policy**: untagged images expire after 7 days; only the 10 most recent tagged images are retained per repository — keeps repositories bounded without manual cleanup.

---

## 10. Compliance service outage — wallet-service balance check failure

**Date:** August 2, 2026 · **Severity:** High (single endpoint fully unavailable)

**Symptom:** `compliance-service` was stopped (simulated dependency outage) to test resilience. `wallet-service`'s `/wallet/{address}/balance` endpoint had no timeout or exception handling around its call to `compliance-service`, so every request during the outage returned a generic, uninformative `500 Internal Server Error`.

**Detection — three independent signals, cross-verified:**
1. **Grafana** — Error Rate panel spiked to ~60% for the affected endpoint
2. **Structured logs** — full Python traceback pinpointed the exact failing line (`requests.get()` call to `compliance-service`)
3. **Jaeger** — the failed span independently captured the same exception (`ConnectionError` / `NameResolutionError`) as a span attribute, `span.kind: client`, confirming the failure occurred at the network call and never reached compliance-service at all

**Root cause:** when `compliance-service` was stopped, Docker Compose removed its DNS entry from the internal network. The unprotected `requests.get()` call raised an unhandled `NameResolutionError`, crashing the request with a generic `500` instead of a controlled failure.

**Fix:** added an explicit timeout (`timeout=3`) and exception handling around the call. On failure, the endpoint now returns a clean `503 Service Unavailable` ("compliance check unavailable, cannot proceed") with a structured log entry.

**Design decision — fail closed, not fail open:** unlike the CoinGecko price integration (which retries and eventually returns a generic unavailable message), the compliance check deliberately **fails closed** — if compliance-service is unreachable, the balance check is refused entirely rather than silently bypassed. In regulated financial infrastructure, silently skipping a compliance check during an outage is a more serious risk than temporary unavailability.

**Verified** under both failure (consistent `503`s) and recovery (restarted, normal `200`, response time back to ~0.3s baseline).

**Follow-ups identified:** apply the same timeout/exception pattern proactively to future outbound calls rather than reactively; wire up a real alert notification channel (only a placeholder contact point exists); consider a circuit breaker if call volume grows; evaluate redundancy for compliance-service itself.

---

## Operational runbook — High Error Rate alert

**Alert:** fires when error rate > 10% for 1 minute · **Dashboard:** Crypto Wallet API - Overview → Error Rate (%) panel

**First steps:**
1. Check which endpoint is affected — the Error Rate panel breaks down by handler
2. Check `wallet-service` logs: `docker logs crypto-wallet-api-wallet-service-1 --tail 50`
3. Check Jaeger for the failing trace (`span.kind` and `otel.status_description` pinpoint the precise failure)

**Known causes:**
- **CoinGecko rate limit (429)** — `/price/{coin}` returns `503`. Self-resolves once the rate-limit window passes; see the retry/backoff pattern in `wallet-service/main.py` (`fetch_price_from_coingecko`).
- **compliance-service unreachable** — `/wallet/{address}/balance` returns `503`. Check `docker compose ps compliance-service`; restart with `docker compose start compliance-service` if stopped. Full incident writeup: see #10 above.

**Escalation:** no real on-call/paging configured for this project (placeholder contact point only). In production, this would route to an on-call rotation / Slack channel.

---

## 12. CI race condition — concurrent pipelines rejected on git push

**Symptom:** when both `wallet-service` and `compliance-service` CI pipelines ran concurrently (both committing an image-tag bump back to `main`), the second pipeline's `git push` failed:

! [rejected] main -> main (fetch first)

**Root cause:** both pipelines checked out the same starting commit, each made its own local commit, and the pipeline that pushed second was rejected as a non-fast-forward — the first push had already advanced `main` in the remote, and Git correctly refused to silently overwrite it.

**Fix:** added `git pull --rebase origin main` immediately before `git push` in both workflows — replaying the local commit on top of whatever the other pipeline had already pushed, rather than failing outright.

**Verified:** re-triggered both pipelines simultaneously; both committed and pushed successfully in sequence with no manual intervention.

**Lesson:** any CI pattern where multiple pipelines commit back to the same branch (a real, common shape for GitOps image-tag automation) needs to account for concurrent-push conflicts explicitly — this isn't hypothetical, it reproduced on the very first concurrent test.