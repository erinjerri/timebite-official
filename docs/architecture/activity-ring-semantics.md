# Execution ring semantics

100% means actual active seconds divided by planned seconds. A session uses its saved target duration. A daily ring sums active session intervals clipped to that local day, divided by targets of actions planned/created that day plus actions actually executing or completing that day. Each Action target is included once. Sessions sum, completion does not manufacture execution credit, and pauses contribute zero. No target/no activity is zero. Overflow clamps visually to one while duration remains visible.

Calendar planned occupancy and Health observations are separate Today summaries and never execution credit. TodayActivitySummary retains merged occupied-time statistics for informational use, not as the execution ring. Day length follows Calendar, including daylight saving time.
