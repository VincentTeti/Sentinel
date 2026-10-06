#!/usr/bin/env bash

if [[ -z "${DISK_WARN:-}" || -z "${DISK_CRIT:-}" ]]; then
    echo "DISK_WARN/DISK_CRIT not set"
    exit 3
fi

used=$(df --output=pcent / | tail -n 1 | tr -dc '0-9')

if [[ -z "$used" ]]; then
    echo "could not read disk usage"
    exit 3
fi

if (( used >= DISK_CRIT )); then
    echo "/ is ${used}% used (critical at ${DISK_CRIT})"
    exit 2
elif (( used >= DISK_WARN )); then
    echo "/ is ${used}% used (warn at ${DISK_WARN})"
    exit 1
else
    echo "/ is ${used}% used (warn at ${DISK_WARN})"
    exit 0
fi
