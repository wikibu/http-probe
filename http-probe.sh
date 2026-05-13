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

    LOG_FILE="$(pwd)/probe-results-$(date +%Y%m%d-%H%M%S).log"
    echo "日志文件: $LOG_FILE" > "$LOG_FILE"

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
        echo "=== 最终统计 ==="
        if [[ -n "$ALL_CODES" ]]; then
            print_stats
        else
            echo "total: 0"
        fi
        echo "=== 统计结束 ==="

        {
            echo ""
            echo "=== 最终统计 ==="
            if [[ -n "$ALL_CODES" ]]; then
                print_stats
            else
                echo "total: 0"
            fi
            echo "=== 统计结束 ==="
        } >> "$LOG_FILE" 2>/dev/null || true
    }

    trap print_final_summary EXIT

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

=== 非200响应 ===
时间: $timestamp
URL: $URL
状态码: $http_code
响应头:
${headers:-（无响应头）}
================
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
