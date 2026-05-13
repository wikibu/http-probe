#!/usr/bin/env bash
set -euo pipefail

INTERVAL=1
COUNT=0
URL=""

usage() {
    echo "用法: $0 <URL> [-i <interval>] [-c <count>]"
    echo ""
    echo "参数:"
    echo "  URL          目标地址（必填）"
    echo "  -i interval  请求间隔（秒），默认 1"
    echo "  -c count     探测次数，默认 0（无限，直到 Ctrl+C）"
    echo "  -h           打印帮助信息"
    exit 1
}

parse_args() {
    if [[ $# -eq 0 ]]; then
        usage
    fi

    # Check for -h anywhere in arguments
    for arg in "$@"; do
        if [[ "$arg" == "-h" ]]; then
            usage
        fi
    done

    # Parse options; URL is the first positional (non-option) argument
    URL="$1"
    shift

    while getopts ":i:c:" opt; do
        case "$opt" in
            i) INTERVAL="$OPTARG" ;;
            c) COUNT="$OPTARG" ;;
            *) usage ;;
        esac
    done

    if [[ -z "$URL" ]]; then
        usage
    fi

    if ! [[ "$INTERVAL" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        echo "错误: interval 必须是数字" >&2
        exit 1
    fi

    if ! [[ "$COUNT" =~ ^[0-9]+$ ]]; then
        echo "错误: count 必须是正整数" >&2
        exit 1
    fi
}

main() {
    parse_args "$@"
    echo "开始探测: $URL"
    echo "间隔: ${INTERVAL}s, 次数: ${COUNT:-无限}"
}

main "$@"
