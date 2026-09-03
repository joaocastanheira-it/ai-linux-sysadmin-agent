#!/usr/bin/env bash

readonly DISK_WARNING="${DISK_WARNING:-80}"
readonly DISK_CRITICAL="${DISK_CRITICAL:-90}"
readonly MEMORY_WARNING="${MEMORY_WARNING:-80}"
readonly MEMORY_CRITICAL="${MEMORY_CRITICAL:-90}"
readonly VERSION="0.3.0"

warning_count=0
critical_count=0

show_help() {
    cat <<EOF
Usage: ${0##*/} [OPTION]

AI-assisted Linux system health monitoring tool.

Options:
  -h, --help       Show this help message
  -v, --version    Show the program version
      --json       Display results in JSON format
Exit codes:
  0    System healthy
  1    Warning detected
  2    Critical condition detected
  64   Invalid command-line option
EOF
}

print_header() {
    echo "=================================="
    echo " AI Linux SysAdmin Agent"
    echo " System Health Check"
    echo "=================================="
}

show_system_info() {
    echo
    echo "[SYSTEM]"
    echo "Hostname: $(hostname)"
    echo "User: $(whoami)"
    echo "Date: $(date)"
    echo "Uptime: $(uptime -p)"
}

classify_usage() {
    local usage="$1"
    local warning="$2"
    local critical="$3"

    if (( usage >= critical )); then
        printf "CRITICAL"
    elif (( usage >= warning )); then
        printf "WARNING"
    else
        printf "OK"
    fi
}

report_usage() {
    local resource="$1"
    local usage="$2"
    local warning="$3"
    local critical="$4"
    local status

    status=$(classify_usage "$usage" "$warning" "$critical")

    case "$status" in
        CRITICAL)
            echo "CRITICAL: ${resource} usage is ${usage}%"
            critical_count=$((critical_count + 1))
            ;;
        WARNING)
            echo "WARNING: ${resource} usage is ${usage}%"
            warning_count=$((warning_count + 1))
            ;;
        OK)
            echo "OK: ${resource} usage is ${usage}%"
            ;;
    esac
}

check_memory() {
    local memory_usage

    echo
    echo "[MEMORY]"
    free -h

    memory_usage=$(free | awk '/Mem:/ {printf "%.0f", $3/$2 * 100}')
    report_usage "Memory" "$memory_usage" "$MEMORY_WARNING" "$MEMORY_CRITICAL"
}

check_disk() {
    local disk_usage

    echo
    echo "[DISK USAGE]"
    df -h /

    disk_usage=$(df -P / | awk 'NR==2 {print $5}' | tr -d '%')
    report_usage "Disk" "$disk_usage" "$DISK_WARNING" "$DISK_CRITICAL"
}

show_system_load() {
    echo
    echo "[SYSTEM LOAD]"
    uptime
}

show_json() {
    local memory_usage
    local disk_usage
    local memory_status
    local disk_status
    local overall_status
    local exit_code

    memory_usage=$(free | awk '/Mem:/ {printf "%.0f", $3/$2 * 100}')
    disk_usage=$(df -P / | awk 'NR==2 {print $5}' | tr -d '%')

    memory_status=$(classify_usage \
        "$memory_usage" \
        "$MEMORY_WARNING" \
        "$MEMORY_CRITICAL")

    disk_status=$(classify_usage \
        "$disk_usage" \
        "$DISK_WARNING" \
        "$DISK_CRITICAL")

    if [[ "$memory_status" == "CRITICAL" || "$disk_status" == "CRITICAL" ]]; then
        overall_status="CRITICAL"
        exit_code=2
    elif [[ "$memory_status" == "WARNING" || "$disk_status" == "WARNING" ]]; then
        overall_status="WARNING"
        exit_code=1
    else
        overall_status="HEALTHY"
        exit_code=0
    fi

    cat <<EOF
{
  "timestamp": "$(date --iso-8601=seconds)",
  "hostname": "$(hostname)",
  "memory": {
    "usage_percent": $memory_usage,
    "status": "$memory_status"
  },
  "disk": {
    "usage_percent": $disk_usage,
    "status": "$disk_status"
  },
  "overall_status": "$overall_status",
  "exit_code": $exit_code
}
EOF

    return "$exit_code"
}

show_summary() {
    echo
    echo "[SUMMARY]"

    if (( critical_count > 0 )); then
        echo "Overall status: CRITICAL"
        return 2
    elif (( warning_count > 0 )); then
        echo "Overall status: WARNING"
        return 1
    else
        echo "Overall status: HEALTHY"
        return 0
    fi
}

    main() {
    case "${1:-}" in
        -h|--help)
            show_help
            return 0
            ;;
        -v|--version)
            echo "${0##*/} ${VERSION}"
            return 0
            ;;
        --json)
            show_json
            return $?
            ;;
        "")
            print_header
            show_system_info
            check_memory
            check_disk
            show_system_load
            show_summary
            ;;
        *)
            echo "ERROR: Unknown option: $1" >&2
            echo "Try '${0##*/} --help' for usage information." >&2
            return 64
            ;;
    esac
}

main "$@"
exit $?
