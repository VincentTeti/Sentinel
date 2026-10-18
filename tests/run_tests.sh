#!/usr/bin/env bash
# Sentinel tests: fake checks in a temp folder. Never touches the real server.
set -u   # no -e: we want to keep going after a failed test

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PASS=0
FAIL=0

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

assert_eq() {   # assert_eq expected actual "description"
    local expected=$1 actual=$2 desc=$3
    if [[ "$expected" == "$actual" ]]; then
        printf 'PASS  %s\n' "$desc"
        PASS=$((PASS + 1))
    else
        printf 'FAIL  %s (expected [%s], got [%s])\n' "$desc" "$expected" "$actual"
        FAIL=$((FAIL + 1))
    fi
}

# A throwaway config: every path points inside $TMP, healing off, mail dry-run
write_conf() {
    mkdir -p "$TMP/checks" "$TMP/state" "$TMP/web"
    cat > "$TMP/sentinel.conf" <<EOF
LOG_FILE="$TMP/sentinel.log"
STATE_DIR="$TMP/state"
CHECKS_DIR="$TMP/checks"
LOCK_FILE="$TMP/sentinel.lock"
WEB_DIR="$TMP/web"
HISTORY_FILE="$TMP/state/history.csv"
DISK_WARN=80
DISK_CRIT=90
MEM_WARN=20
MEM_CRIT=10
LOAD_WARN=1.0
LOAD_CRIT=2.0
HTTP_URL="http://localhost:1"
NGINX_ACCESS_LOG="$TMP/access.log"
ERR5XX_WARN=5
ERR5XX_CRIT=20
CONFIRM_AFTER=3
COOLDOWN=1800
ALERT_EMAIL="test@example.invalid"
DRY_RUN=1
AUTO_HEAL=0
HEAL_MAX=3
HEAL_WINDOW=3600
EOF
}

reset() {       # clean slate between tests
    rm -f "$TMP"/checks/* "$TMP"/state/* "$TMP"/sentinel.log
}

make_check() {  # make_check <filename> <exit code> <output line>
    printf '#!/usr/bin/env bash\necho "%s"\nexit %s\n' "$3" "$2" > "$TMP/checks/$1"
    chmod +x "$TMP/checks/$1"
}

run_sentinel() {  # prints the exit code; the output goes to $TMP/out.txt
    SENTINEL_CONF="$TMP/sentinel.conf" "$ROOT/sentinel.sh" > "$TMP/out.txt" 2>&1
    echo $?
}
status_of() {   # status_of <check name>: the status word from the last run's table
    awk -v n="$1" '$1 == n { print $2 }' "$TMP/out.txt"
}

count_alerts() {   # count_alerts <check name>: dry-run alerts logged so far for it
    local n
    n=$(grep -c "DRY RUN notify.*$1" "$TMP/sentinel.log" 2>/dev/null)
    echo "${n:-0}"
}
status_of() {   # status_of <check name>: the status word from the last run's table
    awk -v n="$1" '$1 == n { print $2 }' "$TMP/out.txt"
}

count_alerts() {   # count_alerts <check name>: dry-run alerts logged so far for it
    local n
    n=$(grep -c "DRY RUN notify.*$1" "$TMP/sentinel.log" 2>/dev/null)
    echo "${n:-0}"
}

write_conf

# ---- Tests: runner exit codes ----
reset
make_check 10-ok.sh 0 "all fine"
assert_eq 0 "$(run_sentinel)" "only OK checks: exit code 0"

reset
make_check 10-ok.sh 0 "all fine"
make_check 20-warn.sh 1 "getting full"
assert_eq 1 "$(run_sentinel)" "one WARNING: exit code 1"

reset
make_check 10-ok.sh 0 "all fine"
make_check 20-warn.sh 1 "getting full"
make_check 30-crit.sh 2 "disk dead"
assert_eq 2 "$(run_sentinel)" "one CRITICAL: exit code 2"

# ---- Test: a hanging check becomes UNKNOWN (takes about 12 seconds) ----
reset
make_check 10-ok.sh 0 "all fine"
printf '#!/usr/bin/env bash\nsleep 300\n' > "$TMP/checks/40-hang.sh"
chmod +x "$TMP/checks/40-hang.sh"
run_sentinel > /dev/null
assert_eq UNKNOWN "$(status_of 40-hang)" "hanging check is reported as UNKNOWN"
assert_eq OK "$(status_of 10-ok)" "other checks still run after a hang"

# ---- Test: confirmation count, cooldown, reminder, recovery ----
reset
make_check 30-crit.sh 2 "disk dead"

run_sentinel > /dev/null
assert_eq 0 "$(count_alerts 30-crit)" "confirmation: no alert after run 1"
run_sentinel > /dev/null
assert_eq 0 "$(count_alerts 30-crit)" "confirmation: no alert after run 2"
run_sentinel > /dev/null
assert_eq 1 "$(count_alerts 30-crit)" "confirmation: one alert after run 3"

run_sentinel > /dev/null
assert_eq 1 "$(count_alerts 30-crit)" "cooldown: no repeat alert on run 4"

# Pretend the last alert was long ago, so the cooldown has passed
sed -i 's/^LAST_ALERT=.*/LAST_ALERT=1/' "$TMP/state/30-crit.state"
run_sentinel > /dev/null
assert_eq 2 "$(count_alerts 30-crit)" "cooldown over: reminder alert is sent"

make_check 30-crit.sh 0 "disk fine again"
run_sentinel > /dev/null
assert_eq 3 "$(count_alerts 30-crit)" "recovery: one recovery message is sent"
run_sentinel > /dev/null
assert_eq 3 "$(count_alerts 30-crit)" "recovery: no repeat after it is sent"

# ---- Test: a hanging check becomes UNKNOWN (takes about 12 seconds) ----
reset
make_check 10-ok.sh 0 "all fine"
printf '#!/usr/bin/env bash\nsleep 300\n' > "$TMP/checks/40-hang.sh"
chmod +x "$TMP/checks/40-hang.sh"
RC=$(run_sentinel)
assert_eq UNKNOWN "$(status_of 40-hang)" "hanging check is reported as UNKNOWN"
assert_eq OK "$(status_of 10-ok)" "other checks still run after a hang"

# ---- Test: confirmation count, cooldown, reminder, recovery ----
reset
make_check 30-crit.sh 2 "disk dead"

run_sentinel > /dev/null
assert_eq 0 "$(count_alerts 30-crit)" "confirmation: no alert after run 1"
run_sentinel > /dev/null
assert_eq 0 "$(count_alerts 30-crit)" "confirmation: no alert after run 2"
run_sentinel > /dev/null
assert_eq 1 "$(count_alerts 30-crit)" "confirmation: one alert after run 3"

run_sentinel > /dev/null
assert_eq 1 "$(count_alerts 30-crit)" "cooldown: no repeat alert on run 4"

# Pretend the last alert was long ago, so the cooldown has passed
sed -i 's/^LAST_ALERT=.*/LAST_ALERT=1/' "$TMP/state/30-crit.state"
run_sentinel > /dev/null
assert_eq 2 "$(count_alerts 30-crit)" "cooldown over: reminder alert is sent"

make_check 30-crit.sh 0 "disk fine again"
run_sentinel > /dev/null
assert_eq 3 "$(count_alerts 30-crit)" "recovery: one recovery message is sent"
run_sentinel > /dev/null
assert_eq 3 "$(count_alerts 30-crit)" "recovery: no repeat after it is sent"

# ---- Summary ----
printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
exit $(( FAIL > 0 ))
