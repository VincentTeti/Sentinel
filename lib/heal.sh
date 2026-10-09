#!/usr/bin/env bash
# lib/heal.sh - automatic repair actions

heal_nginx() {
    log WARN "healing: restarting nginx"

    if ! sudo -n systemctl restart nginx; then
        log ERROR "healing: restart command failed"
        return 1
    fi

    sleep 3

    if "$CHECKS_DIR/40-nginx-service.sh" >/dev/null 2>&1 \
       && "$CHECKS_DIR/50-nginx-http.sh" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}


maybe_heal() {
    local name="$1" rc="$2"
    local now

    
    [[ "$name" == "40-nginx-service" ]] || return 0
    (( rc != 0 )) || return 0
    [[ "${AUTO_HEAL:-0}" == "1" ]] || return 0

    
    read_state "$name"
    (( FAILS >= CONFIRM_AFTER )) || return 0

    now="$(date +%s)"

    
    if (( now - HEAL_START >= HEAL_WINDOW )); then
        HEAL_COUNT=0
        HEAL_START="$now"
    fi

    
    if (( HEAL_COUNT >= HEAL_MAX )); then
        log WARN "healing: $HEAL_COUNT of $HEAL_MAX attempts used, not trying again yet"
        return 0
    fi

    HEAL_COUNT=$(( HEAL_COUNT + 1 ))

    if heal_nginx; then
        log INFO "healing: nginx is back (attempt $HEAL_COUNT of $HEAL_MAX)"
        notify "[sentinel] HEALED: $name" "nginx was down and was restarted automatically. It is running again (attempt $HEAL_COUNT of $HEAL_MAX in this window)."
    else
        log ERROR "healing: attempt $HEAL_COUNT of $HEAL_MAX failed"
        if (( HEAL_COUNT >= HEAL_MAX )); then
            notify "[sentinel] NEEDS A HUMAN: $name" "nginx is down and $HEAL_MAX automatic restarts have failed. Sentinel will not try again until the window passes. Please check it by hand."
        fi
    fi

    write_state "$name"
}
