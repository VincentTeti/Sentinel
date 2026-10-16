# Sentinel notes
## Phase 2 - Think about

### Why does the 5xx check look at only the last 500 lines?
It evaluate the recent health, isolates spikes, and optimizes performance.

### Why is UNKNOWN different from CRITICAL?
CRITICAL means the systems is failing while UNKOWKN means the system is blind.


State before	This run	What happens
OK	OK	nothing
OK	problem	FAILS=1, remember SINCE=now, no alert
unconfirmed problem	problem	FAILS++; if FAILS reaches CONFIRM_AFTER, send the alert and set LAST_ALERT=now
unconfirmed problem	OK	reset silently (it was a blip)
confirmed problem	problem	if now - LAST_ALERT >= COOLDOWN, send a reminder
confirmed problem	OK	send one "recovered after X minutes" message, then reset

Sudo rule limits Sentinel to restarting nginx so run a test with sudo -k first because sudo cachees the password for 15 minutes. 


LOG_FILE="$HOME/sentinel/sentinel.log"
STATE_DIR="$HOME/sentinel/state"
WEB_DIR=/var/www/sentinel
HISTORY_FILE="$STATE_DIR/history.csv"
LOCK_FILE="/tmp/sentinel.lock"
