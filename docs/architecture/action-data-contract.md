# Canonical Action and adapter contracts

Updated 2026-10-15. `TimeBiteCore.Action` is the canonical persisted task model. Do not add a parallel Task entity. [System architecture](../architecture.md) distinguishes existing implementation from proposals.

## Existing Action JSON semantics

[Action source](https://github.com/erinjerri/timebite-official/blob/8f63494b9923967fbe924fb313be8e9f8b3fe361/TimeBiteCore/Models/Action.swift) uses synthesized Codable. Missing optional fields remain decodable. Existing fixture tests use ISO-8601 dates. The [proposed wire schema](../../schemas/action.schema.json) describes that ISO-8601 interchange profile; it does not change the local store's encoder or install runtime validation.

| Fields | Meaning / constraints |
|---|---|
| `id` | UUID; authority assigns on creation, stable across adapters. |
| `title` | String. Existing model allows blank; proposed draft boundary trims and rejects blank before commit. |
| `notes` | Optional string. |
| `goalID`, `projectID` | Optional UUIDs. Resolve names to existing authorized objects; do not accept arbitrary model-generated IDs. When project and goal are supplied, validate consistency. |
| `plannedStart` | Optional date; proposed wire format ISO-8601 with explicit offset; normalize UTC and keep source timezone in ingestion provenance. |
| `plannedDuration` | Optional finite nonnegative seconds; zero is valid in existing Action validation, but execution requires a finite positive session target. |
| `actualStart`, `actualEnd` | Optional execution dates; end cannot precede start. Owned by execution service. |
| `actualDuration` | Optional finite nonnegative active seconds, excluding pauses; never inferred simply from wall time. |
| `executionState` | `notStarted`, `running`, `paused`, `completed`. |
| `status` | `inbox`, `planned`, `active`, `completed`, `cancelled`; planning lifecycle is distinct from execution state. |
| `createdAt`, `updatedAt` | Required dates; authority-owned. |

```json
{
  "id": "33333333-3333-4333-8333-333333333333",
  "title": "Call manufacturer",
  "plannedDuration": 1800,
  "executionState": "notStarted",
  "status": "inbox",
  "createdAt": "2026-10-15T16:00:00Z",
  "updatedAt": "2026-10-15T16:00:00Z"
}
```

The schema preserves absent optional fields and accepts explicit null for optional values. JSON Schema cannot enforce end-after-start, project/goal relationships or legal lifecycle transitions; domain validation must do so. The wire schema rejects extra fields in v1 to catch provider mistakes. Future additions require version negotiation and migration fixtures; existing Swift decoding may ignore unknown keys and must not be treated as a security validator.

## Proposed draft boundary

`capture → recognition → ActionDraft → normalization → editable confirmation → Action`.

A draft contains only user-editable planning fields, plus envelope metadata: `schemaVersion`, `requestId`, `source` (typed/voice/handwriting/glasses/import), provider/model version, bounded evidence reference, source timezone, unresolved fields and optional confidence. Confidence is informational; it cannot suppress review or grant execution permission. Source metadata stays outside Action until an optional, backward-compatible Codable migration is implemented. Keep raw media in scoped temporary storage rather than embedding it in tasks.

Example proposed draft (not a new persistent task schema):

```json
{
  "schemaVersion": 1,
  "requestId": "44444444-4444-4444-8444-444444444444",
  "source": "glasses",
  "draft": {"title": "Call manufacturer", "plannedDuration": 1800},
  "unresolvedFields": [],
  "requiresConfirmation": true
}
```

The validator limits input sizes, trims titles, rejects invalid durations/dates and resolves authorized references. The authority assigns IDs, timestamps and initial states. All initial AI/imported drafts require user review; manual forms can commit directly through the same validator. Approval binds to the draft revision/hash so a changed model response cannot reuse it. Requests are idempotent by user plus requestId. Model-supplied `actualDuration`, completion or robot commands are rejected rather than normalized into execution.

## Legacy mappings

| Source | Canonical treatment |
|---|---|
| platform `task_id` | Validate UUID or allocate UUID with durable legacy-ID mapping; do not reinterpret arbitrary strings as UUIDs. |
| `duration_minutes`, `time_allotted_minutes` | Choose explicitly documented planned-duration precedence; conflicting values require review. Convert minutes ×60 to `plannedDuration`. |
| `time_spent_minutes` | Only verified historical execution imports may populate `actualDuration`; never from AI or untrusted companion payloads. |
| `pending/running/complete/skipped` | Do not blindly map one status to both Action and session state. Pending can become inbox/notStarted. Historical running/complete need session evidence; skipped needs explicit product mapping to cancelled or retained history. |
| `goal_id`, `label_id`, `category` | Resolve goal ID; retain labels/categories in migration provenance until an explicit domain extension exists. Work labels and Goal life areas remain distinct. |
| `elapsed_minutes`, `percent_complete` | Drop incoming derived values and recompute from authoritative sessions. |
| CYRA `id/title/priority/status` | ID mapping and title become a draft; priority has no current Action field. Do not silently turn priority into duration or status into completion. |
| Prior conversation `priority`, `due_at`, `project` | Draft suggestions only. Deadline is not `plannedStart`; project name requires resolution. No current priority/deadline field is invented. |

## Sessions, projections and commands

ActivitySession owns `id`, `actionID`, `startedAt`, optional `pausedAt/completedAt`, `accumulatedDuration`, positive `targetDuration`, `status`, optional `runningSince`, `activeIntervals`, and `revision`. Store transitions, not countdown ticks. Drafts cannot create these fields. Future wire codecs need round-trip fixtures for all states, midnight, pauses and revisions before rollout.

Existing CompanionState version 1 contains `asOf`, day bounds, `active`, up to 50 prioritized `actions`, and aggregate `periods`; CompanionAction includes title and optional session. It excludes raw Health samples and calendar titles, but period aggregates include health/calendar seconds. Therefore it is not suitable for every recipient: glasses and studio consumers should receive narrower projections, with health aggregates removed by default. No notes, credentials or unrelated user content belong in those projections.

Current command example, matching CompanionCommand's Codable names:

```json
{
  "id": "55555555-5555-4555-8555-555555555555",
  "type": "pause",
  "actionID": "33333333-3333-4333-8333-333333333333",
  "sessionID": "66666666-6666-4666-8666-666666666666",
  "revision": 3
}
```

A start request omits sessionID/revision and requires no current session; other controls require matching current session and revision. Production auth, expiry, durable idempotency, authority epoch and atomic acknowledgement are proposed wrappers, not fields that already exist in this struct. Completion becomes visible only after successful persistence; projected feedback never proves completion by itself.
