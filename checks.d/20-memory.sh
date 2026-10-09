#!/usr/bin/env bash

if [[ -z "${MEM_WARN:-}" || -z "${MEM_CRIT:-}" ]]; then
    echo "MEM_WARN/MEM_CRIT not set"
    exit 3
fi

total=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
available=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)

if [[ -z "$total" || -z "$available" || "$total" -eq 0 ]]; then
    echo "could not read memory info"
    exit 3
fi

pct=$(( 100 * available / total ))

if (( pct < MEM_CRIT )); then
    echo "only ${pct}% memory available (critical below ${MEM_CRIT}%)"
    exit 2
elif (( pct < MEM_WARN )); then
    echo "only ${pct}% memory available (warn below ${MEM_WARN}%)"
    exit 1
else
    echo "${pct}% memory available (warn below ${MEM_WARN}%)"
    exit 0
fi
