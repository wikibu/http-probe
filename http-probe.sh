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
}

main "$@"
