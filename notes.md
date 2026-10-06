# Sentinel notes
## Phase 2 - Think about

### Why does the 5xx check look at only the last 500 lines?
It evaluate the recent health, isolates spikes, and optimizes performance.

### Why is UNKNOWN different from CRITICAL?
CRITICAL means the systems is failing while UNKOWKN means the system is blind.
