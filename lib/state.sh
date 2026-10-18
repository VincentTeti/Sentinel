# shellcheck shell=bash
read_state() {
    local name="$1"
    local file="$STATE_DIR/$name.state"
    local key value

    FAILS=0
    SINCE=0
    LAST_ALERT=0
    HEAL_COUNT=0
    HEAL_START=0

    [[ -f "$file" ]] || return 0

    while IFS='=' read -r key value; do
        [[ "$value" =~ ^[0-9]+$ ]] || continue   # ignore anything that is not a plain number
        value=$(( 10#$value ))                    # force base 10, so "08" is not read as octal
        case "$key" in
            FAILS)      FAILS="$value" ;;
            SINCE)      SINCE="$value" ;;
            LAST_ALERT) LAST_ALERT="$value" ;;
            HEAL_COUNT) HEAL_COUNT="$value" ;;
            HEAL_START) HEAL_START="$value" ;;
        esac                                      # unknown keys are ignored
    done < "$file"
}

write_state() {
    local name="$1"
    local file="$STATE_DIR/$name.state"
    local tmp

    mkdir -p "$STATE_DIR"
    tmp="$(mktemp "$STATE_DIR/.$name.XXXXXX")"
    printf 'FAILS=%s\nSINCE=%s\nLAST_ALERT=%s\nHEAL_COUNT=%s\nHEAL_START=%s\n' "$FAILS" "$SINCE" "$LAST_ALERT" "$HEAL_COUNT" "$HEAL_START" > "$tmp"
    mv "$tmp" "$file"
}


format_duration() {
    local secs="$1"
    if (( secs >= 3600 )); then
        printf '%dh %dm' $(( secs / 3600 )) $(( secs % 3600 / 60 ))
    elif (( secs >= 60 )); then
        printf '%dm %ds' $(( secs / 60 )) $(( secs % 60 ))
    else
        printf '%ds' "$secs"
    fi
}


update_state() {
    local name="$1" rc="$2" message="$3"
    local now status duration
    now="$(date +%s)"
    status="$(status_word "$rc")"

    read_state "$name"

    if (( rc == 0 || rc == 1 )); then
        # Healthy. A WARNING is logged but never alerts.
        if (( rc == 1 )); then
            log WARN "$name: $message"
        fi
        # Recovery message only if the problem had been confirmed
        if (( FAILS >= CONFIRM_AFTER )); then
            duration="$(format_duration $(( now - SINCE )))"
            notify "[sentinel] RECOVERED: $name" "$name recovered after $duration. Now: $message"
        fi
        FAILS=0
        SINCE=0
        LAST_ALERT=0
    else
        # Problem: CRITICAL or UNKNOWN
        if (( FAILS == 0 )); then
            SINCE="$now"
        fi
        FAILS=$(( FAILS + 1 ))

        if (( FAILS == CONFIRM_AFTER )); then
            notify "[sentinel] $status: $name" "$name is $status: $message"
            LAST_ALERT="$now"
        elif (( FAILS > CONFIRM_AFTER )) && (( now - LAST_ALERT >= COOLDOWN )); then
            duration="$(format_duration $(( now - SINCE )))"
            notify "[sentinel] STILL $status: $name" "$name has been $status for $duration: $message"
            LAST_ALERT="$now"
        fi
    fi

    write_state "$name"
}
