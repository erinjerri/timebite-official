# Incremental implementation plan

Updated 2026-10-15. These are proposed milestones, not claims of shipped functionality. Keep each increment small enough for an independently reviewable change. No paid compute or hardware actuation is part of the documentation update.

| Stage | Work and owner | Dependencies | Exit evidence |
|---|---|---|---|
| 0 — Contract baseline | `timebite-official`: adopt these docs and ISO-8601 Action wire schema; preserve existing fixture JSON; record board/OS/SDK matrix. Add short pointers in platform/CYRA docs to the canonical Action contract after adoption. | None | Schema validates existing five Action fixtures; source fields/enums match; documentation status reconciled. |
| 1 — One ingestion boundary | Official core/service boundary: implement ActionDraft and ActionNormalizer used by manual and existing handwriting capture. Add size limits, positive execution target checks, reference resolution, timezone ambiguity and editable confirmation. | 0 | Typed and OCR input produce the same Action; blank/nonfinite/ambiguous inputs rejected or reviewed; legacy fixtures remain decodable; relaunch retains confirmed Action. |
| 2 — Prove existing companions | Official Apple adapter owner plus hardware repo: real iPhone–Watch tests; Mac companion and actual CoreS3 SE relay QA; distinguish local Mac actions from phone-owned state. | 0 | Start/pause/resume/complete each persist once; stale/revision mismatch rejected; phone suspension, relay restart and disconnect show stale state; offline controls never replay. Record signed device results. |
| 3 — Evaluation harness | CYRA evaluation owner: extract reusable fixtures/container runner, real measured metrics, UUID run IDs, hashed manifests, redacted logs. Keep demo task storage out of production. | 1 | Reproducible baseline with labeled held-out corpus, per-slice accuracy, latency/cost and typed rejection rates; fixed CYRA scores excluded. |
| 4 — Lambda pilot | Infrastructure/evaluation owner: verify credits/expiry/terms/capacity/prices, prepare data locally, run a capped baseline/comparison batch with external termination watchdog. | 3 and account verification | Immutable model/dataset/container manifests, actual billed-cost estimate and measured quality; results exported; instance termination confirmed; storage charges accounted for. No improvement means no tuning spend. |
| 5 — Optional inference gateway | Shared AI service owner: provider-neutral API, auth, per-tenant isolation, quotas, consent/redaction, timeout/cancellation and cost accounting. Add Nebius only after capability and billing checks. | 1, 3 | Contract tests against local fake and selected provider; timeout/quota/provider outage preserve manual loop; no client keys; no task/robot mutation from generated content. |
| 6 — Meta capture | Mobile adapter owner: pin DAT version and supported device capabilities, explicit capture session and visible consent, phone preview/review, minimal feedback. | 1; 5 only for cloud path | Physical glasses voice/photo → approved Action on phone; revoked permission/disconnect/unsupported device tested; no unrestricted Meta assistant or display assumption. |
| 7 — Production authority and sync | Official sync/service owner: authenticated TLS pairing, durable transactional command journal, principal scoping, authority ID/epoch and explicit lease/handoff protocol; retain local-first execution. | 2 | Concurrent starts, duplicate delivery after restart, expired commands, partitions and ownership transfer tested; one active authoritative session; rollback to local mode rehearsed. No Internet exposure of development relay. |
| 8 — visionOS and Android XR | Native client owners: verify Vision window first; Android phone/projected glasses adapter and emulator; implement wire conformance in Kotlin. Spatial presentation follows proven basic interaction. | 0, 1; 7 for remote mutations | Cross-language Action/session round trips, permissions/capability fallback and read-only offline state pass; same session across platforms only after authority tests. |
| 9 — ABC feedback and robotics | Hardware owner: screen/LED celebration from confirmed events; separate behavior protocol and pairing; calibrated firmware safety state machine before motion. | 2; production remote use requires 7 | Duplicate/replay/expiry cannot repeat behavior; local stop/watchdog/stall/link-loss enter safe state. Motion remains disabled until actual actuator/enclosure/power limits are documented and bench-tested. |
| 10 — Tagimata and selective tuning | Studio adapter owner: independent tagging/media dataset and tenant; reuse gateway/eval infrastructure. Tune only against demonstrated error slices and verify export/device suitability. | 3, 5; 4 if GPU work needed | Rights/consent and isolation verified, studio metrics improve held-out baseline without TimeBite regression; versioned artifact promoted with rollback. |

## Suggested first three implementation changes

1. ActionDraft/normalizer plus typed/OCR acceptance fixtures, keeping Action Codable compatibility.
2. Companion QA and durable command-processing design, based on current Watch and relay implementation.
3. CYRA evaluation runner with measured outputs and an offline labeled baseline before any GPU provisioning.

## Test strategy and rollout gates

Use domain tests for illegal transitions, positive targets, repeated completion, interval clipping and daylight saving. Use contract tests for Swift/Kotlin/Python dates, optional values, UUIDs, units, enum spelling and unknown fields. Use transport tests for pending versus applied, duplicated/stale/reordered requests and reconnect. Use real devices for Watch background/reachability, permission prompts and glasses capture; emulator success alone is insufficient. Use hardware bench tests for firmware safety.

AI acceptance targets and corpus design are in the architecture overview. Keep feature flags for capture, cloud inference, remote mutations and robotic feedback independent. Enable local draft creation first, then selected paired users, then external transport. Each stage must preserve manual creation and local execution when disabled. Model rollback selects the previous pinned artifact; sync rollback stops remote controls without discarding local persisted sessions. Record build/device/network versions and measured results at each milestone rather than marking a feature done from source inspection alone.

## Decisions still requiring implementation evidence

- Exact production sync storage/hosting and lease mechanism; do not assume CloudKit serves Android.
- Supported Meta/Android hardware and SDK release, available permissions and distribution path.
- CoreS3 versus SE peripheral inventory, actual actuators and calibrated limits.
- Actual Lambda/Nebius account balances, expiration, promotional eligibility and live capacity.
- Reflection/deadline/priority extensions, if product requirements justify them; no schema expansion is included here.
