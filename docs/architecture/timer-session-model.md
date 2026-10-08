# Timer and session model

ActivitySession is authoritative. runningSince plus persisted closed ActiveIntervals derives elapsed time. Pause closes an interval; resume opens another; completion closes the last interval and is idempotent. UI TimelineView requests rendering each second; it does not increment elapsed time. Clock rollback transitions fail; negative live intervals clamp to zero.

LocalActivityStore writes Action and session changes in one encoded snapshot. Only one unfinished session is permitted; completed/cancelled Actions cannot start. Daily totals are recomputed from persisted intervals, clipped to local half-open day boundaries. Tests reconstruct stores through create/start/pause/resume/complete ten times; actual process termination and device sleep still require runtime validation.
