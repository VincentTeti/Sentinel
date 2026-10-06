#!/usr/bin/env bash

if [[ -z "${NGINX_ACCESS_LOG:-}" || -z "${ERR5XX_WARN:-}" || -z "${ERR5XX_CRIT:-}" ]]; then
    echo "NGINX_ACCESS_LOG/ERR5XX_WARN/ERR5XX_CRIT not set"
    exit 3
fi

if [[ ! -r "$NGINX_ACCESS_LOG" ]]; then
    echo "cannot read $NGINX_ACCESS_LOG (check file permissions)"
    exit 3
fi

result=$(tail -n 500 "$NGINX_ACCESS_LOG" | awk '
    { total++; if ($9 ~ /^5[0-9][0-9]$/) bad++ }
    END { print total+0, bad+0 }')

total=${result% *}
bad=${result#* }

if (( total == 0 )); then
    echo "no requests in the log yet"
    exit 0
fi

pct=$(( 100 * bad / total ))

if (( pct >= ERR5XX_CRIT )); then
    echo "${bad} of last ${total} requests were 5xx (${pct}%, critical at ${ERR5XX_CRIT}%)"
    exit 2
elif (( pct >= ERR5XX_WARN )); then
    echo "${bad} of last ${total} requests were 5xx (${pct}%, warn at ${ERR5XX_WARN}%)"
    exit 1
else
    echo "${bad} of last ${total} requests were 5xx (${pct}%, warn at ${ERR5XX_WARN}%)"
    exit 0
fi
