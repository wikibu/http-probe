#!/usr/bin/env bash
set -euo pipefail

INTERVAL=1
COUNT=0
URL=""
ALL_CODES=""
TOTAL=0
LOG_FILE=""

usage() {
    local exit_code="${1:-1}"
    echo "Usage: $0 <URL> [-i <interval>] [-c <count>]"
    echo ""
    echo "Options:"
    echo "  URL          Target address (required)"
    echo "  -i interval  Request interval in seconds, default 1"
    echo "  -c count     Probe count, default 0 (infinite, until Ctrl+C)"
    echo "  -h           Print help message"
    exit "$exit_code"
}

parse_args() {
    if [[ $# -eq 0 ]]; then
        usage
    fi

    # Extract URL (first non-option argument), then parse options from the rest
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -i)
                [[ -z "${2:-}" ]] && usage
                INTERVAL="$2"
                shift 2
                ;;
            -c)
                [[ -z "${2:-}" ]] && usage
                COUNT="$2"
                shift 2
                ;;
            -h)
                usage 0
                ;;
            -*)
                usage
                ;;
            *)
                if [[ -z "$URL" ]]; then
                    URL="$1"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$URL" ]]; then
        usage
    fi

    if ! [[ "$INTERVAL" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        echo "Error: interval must be a non-negative number" >&2
        exit 1
    fi

    if ! [[ "$COUNT" =~ ^[0-9]+$ ]]; then
        echo "Error: count must be a non-negative integer" >&2
        exit 1
    fi
}

main() {
    parse_args "$@"
    echo "Starting probe: $URL"
    echo "Interval: ${INTERVAL}s, Count: ${COUNT:-infinite}"

    LOG_FILE="$(pwd)/probe-results-$(date +%Y%m%d-%H%M%S).log"
    echo "Log file: $LOG_FILE" > "$LOG_FILE"

    # bash 3.2 (macOS default) does not support declare -A, so use a space-separated
    # string + sort|uniq -c for counting. Fine for typical probe counts.
    ALL_CODES=""
    TOTAL=0
    local current=0

    print_stats() {
        local line
        line=$(echo "$ALL_CODES" | tr ' ' '\n' | sort | uniq -c | awk '{printf "[%s] %s | ", $2, $1}')
        line="${line% |}"
        line="${line}total: ${TOTAL}"
        echo "$line"
    }

    print_final_summary() {
        echo ""
        echo "=== Final Statistics ==="
        if [[ -n "$ALL_CODES" ]]; then
            print_stats
        else
            echo "total: 0"
        fi
        echo "=== End of Statistics ==="

        {
            echo ""
            echo "=== Final Statistics ==="
            if [[ -n "$ALL_CODES" ]]; then
                print_stats
            else
                echo "total: 0"
            fi
            echo "=== End of Statistics ==="
        } >> "$LOG_FILE" 2>/dev/null || true
    }

    trap print_final_summary EXIT
    trap 'exit 0' INT TERM

    probe_once() {
        local http_code response
        http_code=$(curl -s -w "%{http_code}" --output /dev/null --max-time 30 "$URL" 2>/dev/null) || http_code="000"

        if [[ "$http_code" != "200" ]]; then
            local timestamp headers
            timestamp=$(date '+%Y-%m-%d %H:%M:%S')
            response=$(curl -s -D - --output /dev/null --max-time 30 "$URL" 2>/dev/null || true)
            headers="$response"

            local block
            block=$(cat <<BLOCK

=== Non-200 Response ===
Time: $timestamp
URL: $URL
Status Code: $http_code
Response Headers:
${headers:-(no response headers)}
====================
BLOCK
)
            echo "$block"
            echo "$block" >> "$LOG_FILE"
        fi

        if [[ -z "$ALL_CODES" ]]; then
            ALL_CODES="$http_code"
        else
            ALL_CODES="$ALL_CODES $http_code"
        fi
        TOTAL=$((TOTAL + 1))

        print_stats
    }

    while true; do
        if [[ "$COUNT" -gt 0 && "$current" -ge "$COUNT" ]]; then
            break
        fi

        probe_once
        current=$((current + 1))

        if [[ "$INTERVAL" != "0" ]]; then
            sleep "$INTERVAL"
        fi
    done
}

main "$@"
