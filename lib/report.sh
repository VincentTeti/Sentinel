# shellcheck shell=bash
declare -A UPTIME=()
declare -A COLOR=([OK]="#2e7d32" [WARNING]="#ef6c00" [CRITICAL]="#c62828" [UNKNOWN]="#757575")
write_history() {
    local now name
    now=$(date +%s)
    mkdir -p "$(dirname "$HISTORY_FILE")"
    for name in "${ORDER[@]}"; do
        printf '%s,%s,%s\n' "$now" "$name" "$(status_word "${STATUS[$name]}")" >> "$HISTORY_FILE"
    done
}

# Make a string safe inside a JSON "..." value
json_escape() {
    local s=$1
    s=${s//\\/\\\\}     
    s=${s//\"/\\\"}      
    s=${s//$'\n'/ }      
    s=${s//$'\t'/ }
    s=${s//$'\r'/ }
    printf '%s' "$s"
}

write_json() {
    local now name first=1 tmp
    now=$(date +%s)
    tmp=$(mktemp "$WEB_DIR/.status.XXXXXX")
    {
        printf '{\n  "generated": %s,\n  "checks": [\n' "$now"
        for name in "${ORDER[@]}"; do
            (( first )) || printf ',\n'
            first=0
            printf '    {"name": "%s", "status": "%s", "message": "%s"}' \
                "$(json_escape "$name")" \
                "$(json_escape "$(status_word "${STATUS[$name]}")")" \
                "$(json_escape "${MESSAGE[$name]}")"
        done
        printf '\n  ]\n}\n'
    } > "$tmp"
    chmod 644 "$tmp"                  
    mv "$tmp" "$WEB_DIR/status.json"  
}

# Make text safe inside HTML (& must be first; \& stops bash 5.2 treating & as "the match")
html_escape() {
    local s=$1
    s=${s//&/\&amp;}
    s=${s//</\&lt;}
    s=${s//>/\&gt;}
    s=${s//\"/\&quot;}
    printf '%s' "$s"
}

# Fill UPTIME[check]=percent of runs that were OK in the last 24 hours
compute_uptime() {
    local since check pct
    since=$(( $(date +%s) - 86400 ))
    UPTIME=()
    while read -r check pct; do
        UPTIME[$check]=$pct
    done < <(awk -F, -v since="$since" '
        $1 >= since { n[$2]++; if ($3 == "OK") ok[$2]++ }
        END { for (c in n) printf "%s %.1f\n", c, 100 * ok[c] / n[c] }
    ' "$HISTORY_FILE")
}

write_html() {
    local now name st color up tmp
    now=$(date '+%Y-%m-%d %H:%M:%S')
    compute_uptime
    tmp=$(mktemp "$WEB_DIR/.index.XXXXXX")
    {
        cat <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta http-equiv="refresh" content="30">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Sentinel status</title>
<style>
 body { font-family: sans-serif; margin: 1.5rem; }
 table { border-collapse: collapse; width: 100%; max-width: 60rem; }
 th, td { padding: .5rem .75rem; border-bottom: 1px solid #ddd; text-align: left; }
 .badge { color: #fff; padding: .15rem .6rem; border-radius: .3rem; font-weight: bold; }
</style>
</head>
<body>
<h1>Sentinel status</h1>
<p>Last run: $now</p>
<table>
<tr><th>Check</th><th>Status</th><th>Message</th><th>Uptime (24h)</th></tr>
EOF
        for name in "${ORDER[@]}"; do
            st=$(status_word "${STATUS[$name]}")
            color=${COLOR[$st]:-#757575}
            if [[ -n "${UPTIME[$name]:-}" ]]; then up="${UPTIME[$name]}%"; else up="n/a"; fi
            printf '<tr><td>%s</td><td><span class="badge" style="background:%s">%s</span></td><td>%s</td><td>%s</td></tr>\n' \
                "$(html_escape "$name")" "$color" "$(html_escape "$st")" \
                "$(html_escape "${MESSAGE[$name]}")" "$up"
        done
        printf '</table>\n<p><a href="status.json">status.json</a></p>\n</body>\n</html>\n'
    } > "$tmp"
    chmod 644 "$tmp"
    mv "$tmp" "$WEB_DIR/index.html"
}
