#!/usr/bin/env bash

readonly DISK_WARNING="${DISK_WARNING:-80}"
readonly DISK_CRITICAL="${DISK_CRITICAL:-90}"
readonly MEMORY_WARNING="${MEMORY_WARNING:-80}"
readonly MEMORY_CRITICAL="${MEMORY_CRITICAL:-90}"

warning_count=0
critical_count=0

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

report_usage() {
    local resource="$1"
    local usage="$2"
    local warning="$3"
    local critical="$4"

    if (( usage >= critical )); then
        echo "CRITICAL: ${resource} usage is ${usage}%"
        critical_count=$((critical_count + 1))
    elif (( usage >= warning )); then
        echo "WARNING: ${resource} usage is ${usage}%"
        warning_count=$((warning_count + 1))
    else
        echo "OK: ${resource} usage is ${usage}%"
    fi
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
    print_header
    show_system_info
    check_memory
    check_disk
    show_system_load
    show_summary
}

main "$@"
exit $?
