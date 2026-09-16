# User Workflows

## Learner: input data with speech

1. Open the app
2. Choose the speech input path
3. Speak naturally
4. Review the transcribed result
5. Confirm or correct the captured content
6. Save the finalized input

## Learner: input data with computer vision capture

1. Open the capture flow
2. Point the camera or capture source at the target content
3. Let the app extract structured data
4. Review the extracted result
5. Confirm or edit the result
6. Save the finalized input

## Learner: switch between input modes

The app should make it easy to move between STT and vision capture without losing context.

Recommended behavior:

- Preserve draft state
- Show clearly which capture mode is active
- Avoid forcing the user to restart a capture session unnecessarily

## Admin: prepare the production build

1. Review the current build state
2. Confirm the learner flows are stable
3. Verify configuration and release settings
4. Produce the final production build
5. Approve the release for distribution

## Admin: keep learner and production concerns separate

Admins should be able to manage production concerns without exposing unnecessary controls to learners.

That separation should cover:

- Feature flags
- Release toggles
- Environment-specific configuration
- Build and packaging controls

## Placeholder checklist

- STT happy path
- STT correction path
- Vision capture happy path
- Vision capture correction path
- Admin release readiness checklist
