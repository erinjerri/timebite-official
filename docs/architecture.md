# Architecture Overview

## Purpose

This document describes the high-level shape of the consolidated TimeBite system.

It is intentionally lightweight and meant to be expanded once the repo contains implementation code.

## High-level model

The app should support two core user paths:

1. Learner input capture
2. Admin production release

## Suggested system layers

### Client layer

The client is the learner-facing app surface. It should handle:

- Voice input
- Vision input
- Preview and correction
- Local interaction state

### Capture layer

The capture layer converts raw input into structured data.

Expected responsibilities:

- Transcribe speech into text
- Extract usable signals from visual capture
- Normalize and validate captured content
- Route results into the app state

### Admin layer

The admin layer supports the final production build.

Expected responsibilities:

- Manage release-ready configuration
- Review build state
- Approve the final production package
- Keep learner-facing and production-only controls separated

## Suggested data flow

1. User provides input through speech or visual capture
2. Capture services normalize the input
3. The app presents the captured result for review
4. The learner confirms or edits the result
5. Admin workflows govern the final production build

## Consolidation note

The earlier experimental builds should eventually be mapped into this structure instead of remaining separate product directions.

That means:

- `timebite-macos` becomes part of the learner-facing client story
- `timebite-platform` contributes the broader platform concept
- `CYRA-AgentBeatsHackathon` informs experimentation, prototyping, or research history

## Placeholder sections for later

- Data model reference
- API reference
- Platform-specific implementation notes
- Security and privacy notes
- Release pipeline details
