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
}
