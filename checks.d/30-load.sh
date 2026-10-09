#!/usr/bin/env bash

if [[ -z "${LOAD_WARN:-}" || -z "${LOAD_CRIT:-}" ]]; then
    echo "LOAD_WARN/LOAD_CRIT not set"
    exit 3
fi

load=$(awk '{print $1}' /proc/loadavg)
cores=$(nproc)

if [[ -z "$load" || -z "$cores" ]]; then
    echo "could not read load or CPU count"
    exit 3
fi

per_core=$(awk -v l="$load" -v c="$cores" 'BEGIN { printf "%.2f", l / c }')

if awk -v v="$per_core" -v t="$LOAD_CRIT" 'BEGIN { exit !(v >= t) }'; then
    echo "load is ${per_core} per core (${load} on ${cores} cores, critical at ${LOAD_CRIT})"
    exit 2
elif awk -v v="$per_core" -v t="$LOAD_WARN" 'BEGIN { exit !(v >= t) }'; then
    echo "load is ${per_core} per core (${load} on ${cores} cores, warn at ${LOAD_WARN})"
    exit 1
else
    echo "load is ${per_core} per core (${load} on ${cores} cores, warn at ${LOAD_WARN})"
    exit 0
fi
