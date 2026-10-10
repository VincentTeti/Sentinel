log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "$timestamp [$level] $message" | tee -a "$LOG_FILE"
}

die() {
    log ERROR "$1"
    exit 1
}


load_config() {
    local conf_file="$1"

    if [[ ! -f "$conf_file" ]]; then
        echo "ERROR: config file not found: $conf_file" >&2
        exit 1
    fi

    
    source "$conf_file"

    
    : "${LOG_FILE:?LOG_FILE is missing in $conf_file}"
    : "${STATE_DIR:?STATE_DIR is missing in $conf_file}"
    : "${CHECKS_DIR:?CHECKS_DIR is missing in $conf_file}"
    : "${LOCK_FILE:?LOCK_FILE is missing in $conf_file}"
    : "${DISK_WARN:?DISK_WARN is missing in $conf_file}"
    : "${DISK_CRIT:?DISK_CRIT is missing in $conf_file}"
    : "${MEM_WARN:?MEM_WARN is missing in $conf_file}"
    : "${MEM_CRIT:?MEM_CRIT is missing in $conf_file}"
    : "${AUTO_HEAL:?AUTO_HEAL is missing in $conf_file}"
    : "${HEAL_MAX:?HEAL_MAX is missing in $conf_file}"
    : "${HEAL_WINDOW:?HEAL_WINDOW is missing in $conf_file}"
    : "${WEB_DIR:?WEB_DIR not set in sentinel.conf}"
    : "${HISTORY_FILE:?HISTORY_FILE not set in sentinel.conf}"
}


notify() {
    local subject="${1//$'\n'/ }"
    local body="$2"

    if [[ "${DRY_RUN:-0}" == "1" ]]; then
        log INFO "DRY RUN notify: [$subject] $body"
        return 0
    fi

    if ! printf 'To: %s\nSubject: %s\n\n%s\n' "$ALERT_EMAIL" "$subject" "$body" | msmtp "$ALERT_EMAIL"; then
        log ERROR "failed to send email: $subject"
    fi
    return 0
}


status_word() {
    case "$1" in
        0) echo "OK" ;;
        1) echo "WARNING" ;;
        2) echo "CRITICAL" ;;
        *) echo "UNKNOWN" ;;
    esac
}
