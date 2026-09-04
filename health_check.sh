#!/usr/bin/env bash

readonly DISK_WARNING="${DISK_WARNING:-80}"
readonly DISK_CRITICAL="${DISK_CRITICAL:-90}"
readonly MEMORY_WARNING="${MEMORY_WARNING:-80}"
readonly MEMORY_CRITICAL="${MEMORY_CRITICAL:-90}"
readonly VERSION="0.5.0"
readonly OPENAI_API_URL="https://api.openai.com/v1/responses"
readonly DEFAULT_OPENAI_MODEL="gpt-5.6-luna"

warning_count=0
critical_count=0

show_help() {
    cat <<'EOF'
Usage: ${0##*/} [OPTION]

AI-assisted Linux system health monitoring tool.

Options:
  -h, --help       Show this help message
  -v, --version    Show the program version
      --json       Display results in JSON format
      --save       Save JSON results to a timestamped file
      --analyze    Analyze system health using the OpenAI API
Exit codes:
  0    System healthy
  1    Warning detected
  2    Critical condition detected
  64   Invalid command-line option
  73   Report file could not be created
  69   Required service unavailable
  70   Invalid or empty API response
  78   Missing API configuration
Environment:
  OPENAI_API_KEY      Required when using --analyze
  OPENAI_MODEL        Optional model override
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

show_api_key_setup() {
    cat >&2 <<'EOF'
To configure an OpenAI API key for the current terminal session:

  1. Create a key at:
     https://platform.openai.com/api-keys

  2. Run:
     read -rsp "OpenAI API key: " OPENAI_API_KEY
     export OPENAI_API_KEY
     echo

The key remains outside the script and is not saved in this repository.
EOF
}

validate_ai_requirements() {
    local command_name

    for command_name in curl jq; do
        if ! command -v "$command_name" >/dev/null 2>&1; then
            echo "ERROR: Required command not found: $command_name" >&2
            return 69
        fi
    done

    if [[ -z "${OPENAI_API_KEY:-}" ]]; then
        echo "ERROR: OPENAI_API_KEY is not configured" >&2
	echo >&2
	show_api_key_setup
	return 78
fi
}

analyze_with_ai() {
    local model="${OPENAI_MODEL:-$DEFAULT_OPENAI_MODEL}"
    local health_json
    local health_exit
    local request_body
    local response
    local analysis

    validate_ai_requirements || return $?

    if health_json=$(show_json); then
        health_exit=0
    else
        health_exit=$?
    fi

    request_body=$(jq -n \
        --arg model "$model" \
        --arg health_json "$health_json" \
        '{
            model: $model,
            instructions: "You are a Linux system administrator. Analyze the supplied system health report. Explain the current state, identify risks, and give concise, safe recommendations. Do not recommend destructive commands.",
            input: ("Analyze this Linux health report:\n" + $health_json)
        }')

    if ! response=$(curl -sS "$OPENAI_API_URL" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $OPENAI_API_KEY" \
        -d "$request_body"); then
        echo "ERROR: Could not connect to the OpenAI API" >&2
        return 69
    fi

    if ! jq -e . >/dev/null 2>&1 <<< "$response"; then
        echo "ERROR: The API returned invalid JSON" >&2
        return 70
    fi

    if jq -e '.error != null' >/dev/null 2>&1 <<< "$response"; then
        jq -r '"ERROR: OpenAI API: \(.error.message)"' \
            <<< "$response" >&2
        return 69
    fi

    analysis=$(jq -r '
        [
            .output[]?.content[]?
            | select(.type == "output_text")
            | .text
        ] | join("\n")
    ' <<< "$response")

    if [[ -z "$analysis" ]]; then
        echo "ERROR: The API returned no analysis" >&2
        return 70
    fi

    printf '%s\n' "$analysis"
    return "$health_exit"
}

save_json_report() {
    local report_dir="${REPORT_DIR:-reports}"
    local filename_timestamp
    local report_file
    local exit_code

    filename_timestamp=$(date +'%Y%m%d_%H%M%S')
    report_file="${report_dir}/health_${filename_timestamp}.json"

    if ! mkdir -p "$report_dir"; then
        echo "ERROR: Could not create report directory: $report_dir" >&2
        return 73
    fi

    if show_json > "$report_file"; then
        exit_code=0
    else
        exit_code=$?
    fi

    echo "Report saved to: $report_file"
    return "$exit_code"
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
        --save)
            save_json_report
            return $?
	    ;;
        --analyze)
            analyze_with_ai
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
