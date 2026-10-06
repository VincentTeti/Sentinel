#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib/common.sh"
load_config "$SCRIPT_DIR/sentinel.conf"

export DISK_WARN DISK_CRIT MEM_WARN MEM_CRIT LOAD_WARN LOAD_CRIT HTTP_URL NGINX_ACCESS_LOG ERR5XX_WARN ERR5XX_CRIT

status_word() {
    case "$1" in
        0) echo "OK" ;;
        1) echo "WARNING" ;;
        2) echo "CRITICAL" ;;
        *) echo "UNKNOWN" ;;
    esac
}

declare -A STATUS MESSAGE
declare -A RANK=([0]=0 [1]=1 [3]=2 [2]=3)
ORDER=()
worst=0

log INFO "sentinel start"


for f in "$CHECKS_DIR"/*.sh; do
    [[ -e "$f" ]] || continue
    name="$(basename "$f" .sh)"

    if [[ ! -x "$f" ]]; then
        log WARN "skipping $name: not executable"
        continue
    fi

    out=$(timeout 10 "$f" 2>&1) && rc=0 || rc=$?

    if (( rc == 124 )); then
        rc=3
        out="check timed out after 10s"
    elif (( rc > 3 )); then
        out="check failed to run (exit $rc): $out"
        rc=3
    fi

    out="${out%%$'\n'*}"
    [[ -n "$out" ]] || out="(no output)"

    STATUS[$name]=$rc
    MESSAGE[$name]="$out"
    ORDER+=("$name")

    if (( ${RANK[$rc]} > ${RANK[$worst]} )); then
        worst=$rc
    fi
done

if (( ${#ORDER[@]} == 0 )); then
    die "no checks found in $CHECKS_DIR"
fi

printf '%-22s %-10s %s\n' "CHECK" "STATUS" "MESSAGE"
for name in "${ORDER[@]}"; do
    printf '%-22s %-10s %s\n' "$name" "$(status_word "${STATUS[$name]}")" "${MESSAGE[$name]}"
done

log INFO "sentinel finished: worst status $(status_word "$worst")"
exit "$worst"
