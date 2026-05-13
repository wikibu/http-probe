#!/usr/bin/env bash
set -euo pipefail

INTERVAL=1
COUNT=0
URL=""

usage() {
    local exit_code="${1:-1}"
    echo "用法: $0 <URL> [-i <interval>] [-c <count>]"
    echo ""
    echo "参数:"
    echo "  URL          目标地址（必填）"
    echo "  -i interval  请求间隔（秒），默认 1"
    echo "  -c count     探测次数，默认 0（无限，直到 Ctrl+C）"
    echo "  -h           打印帮助信息"
    exit "$exit_code"
}

parse_args() {
    if [[ $# -eq 0 ]]; then
        usage
    fi

    # Parse options first so unknown flags are caught before URL assignment
    while getopts ":i:c:h" opt; do
        case "$opt" in
            i) INTERVAL="$OPTARG" ;;
            c) COUNT="$OPTARG" ;;
            h) usage 0 ;;
            *) usage ;;
        esac
    done
    shift $((OPTIND - 1))

    # URL is the first positional argument
    URL="${1:-}"
    if [[ -z "$URL" ]]; then
        usage
    fi

    if ! [[ "$INTERVAL" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        echo "错误: interval 必须是非负数" >&2
        exit 1
    fi

    if ! [[ "$COUNT" =~ ^[0-9]+$ ]]; then
        echo "错误: count 必须是非负整数" >&2
        exit 1
    fi
}

main() {
    parse_args "$@"
    echo "开始探测: $URL"
    echo "间隔: ${INTERVAL}s, 次数: ${COUNT:-无限}"

    # bash 3.2 (macOS default) does not support declare -A, so use a space-separated
    # string + sort|uniq -c for counting. Fine for typical probe counts.
    local all_codes=""
    local total=0
    local current=0

    print_stats() {
        local line
        line=$(echo "$all_codes" | tr ' ' '\n' | sort | uniq -c | awk '{printf "[%s] %s | ", $2, $1}')
        line="${line% |}"
        line="${line}total: ${total}"
        echo "$line"
    }

    probe_once() {
        local http_code
        http_code=$(curl -s -w "%{http_code}" --output /dev/null --max-time 30 "$URL" 2>/dev/null) || http_code="000"

        if [[ -z "$all_codes" ]]; then
            all_codes="$http_code"
        else
            all_codes="$all_codes $http_code"
        fi
        total=$((total + 1))

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
