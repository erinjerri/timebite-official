# HealthKit boundary

Packages/TimeBiteHealth owns HKHealthStore and provides HealthActivityProvider. Existing reads: sleep, workouts, mindfulness. Sleep includes overlapping/cross-midnight samples, filters asleep stages, merges unique intervals, and clips to the requested day. Workout external identifiers use HealthKit UUIDs. Never synthesize production samples.

UI distinguishes unavailable, authorization required/not requested, requesting, loading, loaded, empty, and failure. HealthKit deliberately does not disclose read denial: successful request completion is not proof of authorization. Empty results may mean no data or read access withheld; describe that honestly. Refresh on foreground only after permission has been requested. Health never blocks local execution.
