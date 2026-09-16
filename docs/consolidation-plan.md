# Consolidation Plan

## Goal

Bring the experimental TimeBite work into a single, clearer product direction.

The working assumption for this repo is:

- Learner-facing capture is the primary user story
- Admin-controlled production release is the operational story
- Older experiments should inform the direction, not compete with it

## Source repositories

### `timebite-macos`

Use this as a source of macOS-specific implementation ideas, UI patterns, and platform behavior.

### `timebite-platform`

Use this as the source of broader platform thinking, shared concepts, and system organization.

### `CYRA-AgentBeatsHackathon`

Use this as historical experimentation and research context for multimodal or agent-driven workflows.

## Consolidation strategy

1. Identify reusable concepts from each repository
2. Map them into the new learner/admin split
3. Remove duplicated or experimental-only assumptions
4. Define the final product vocabulary in one place
5. Replace scattered documentation with this repo as the source of truth

## Documentation migration targets

When the implementation lands, this repo should own:

- Product overview
- Input capture flows
- Admin release workflow
- Architecture reference
- Setup and contribution notes

## Open questions

- Which platform is the primary production target first?
- Which capture sources are officially supported at launch?
- What level of admin access should be exposed in the first build?
- Which experimental features should remain research-only?

## Boilerplate note

This file is deliberately high level. It exists to give the team a shared baseline before the final product architecture is locked in.
