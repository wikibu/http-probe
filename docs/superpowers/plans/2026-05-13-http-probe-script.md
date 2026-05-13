# HTTP 探测脚本实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 编写一个 Shell 脚本，按可配置间隔/次数探测单个 HTTP URL，实时统计 HTTP 状态码，记录非 200 响应的详细信息。

**Architecture:** 单个 Shell 脚本，使用 bash 关联数组做状态码计数，通过 `trap` 处理信号退出，每次请求用 curl 的 `-w` 格式化输出获取状态码。

**Tech Stack:** bash 4+ (关联数组), curl

---

### 文件结构

- `http-probe.sh` — 主脚本，包含所有逻辑：参数解析、主循环、统计打印、信号处理、日志写入
- `test-http-probe.sh` — 基础功能测试脚本（本地验证用）

---

### Task 1: 脚本骨架 + 参数解析

**Files:**
- Create: `http-probe.sh`

- [ ] **Step 1: 创建脚本骨架和参数解析**

```bash
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

    URL="$1"
    shift

    while getopts ":i:c:h" opt; do
        case "$opt" in
            i) INTERVAL="$OPTARG" ;;
            c) COUNT="$OPTARG" ;;
            h) usage ;;
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
```

- [ ] **Step 2: 赋予可执行权限并验证**

```bash
chmod +x http-probe.sh
./http-probe.sh -h
```

期望输出：打印用法并退出。

- [ ] **Step 3: 验证参数错误处理**

```bash
./http-probe.sh 2>&1 || true
./http-probe.sh "http://example.com" -i abc 2>&1 || true
./http-probe.sh "http://example.com" -c abc 2>&1 || true
```

期望输出：三次都打印用法或错误信息并退出码 1。

- [ ] **Step 4: 提交**

```bash
git add http-probe.sh
git commit -m "feat: 添加脚本骨架和参数解析"
```

---

### Task 2: 状态统计 + 主循环

**Files:**
- Modify: `http-probe.sh`

- [ ] **Step 1: 在 main() 函数中添加状态统计和主循环逻辑**

在 `main()` 函数中，`parse_args` 之后、echo 之后，添加以下内容：

```bash
    declare -A status_counts
    local total=0
    local current=0

    print_stats() {
        local line=""
        for code in $(echo "${!status_counts[@]}" | tr ' ' '\n' | sort); do
            line="${line}[${code}] ${status_counts[$code]} | "
        done
        line="${line}total: ${total}"
        echo "$line"
    }

    probe_once() {
        local http_code
        http_code=$(curl -s -w "%{http_code}" --output /dev/null --max-time 30 "$URL" 2>/dev/null) || http_code="000"

        status_counts[$http_code]=$(( ${status_counts[$http_code]:-0} + 1 ))
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
```

- [ ] **Step 2: 提交**

```bash
git add http-probe.sh
git commit -m "feat: 添加主循环和状态码统计"
```

---

### Task 3: 日志文件 + 非 200 响应记录

**Files:**
- Modify: `http-probe.sh`

- [ ] **Step 1: 添加日志文件创建和非 200 处理**

在 `main()` 函数的 `print_stats` 函数之前，添加日志文件初始化：

```bash
    local LOG_FILE
    LOG_FILE="$(pwd)/probe-results-$(date +%Y%m%d-%H%M%S).log"
    echo "日志文件: $LOG_FILE" > "$LOG_FILE"
```

在 `probe_once()` 函数中，获取到 `http_code` 之后、递增计数器之前，添加非 200 处理：

```bash
        if [[ "$http_code" != "200" ]]; then
            local timestamp
            timestamp=$(date '+%Y-%m-%d %H:%M:%S')
            local headers
            headers=$(curl -s -D - --output /dev/null --max-time 30 "$URL" 2>/dev/null)

            echo ""
            echo "=== 非200响应 ==="
            echo "时间: $timestamp"
            echo "URL: $URL"
            echo "状态码: $http_code"
            echo "响应头:"
            echo "$headers"
            echo "================"
            echo ""

            {
                echo ""
                echo "=== 非200响应 ==="
                echo "时间: $timestamp"
                echo "URL: $URL"
                echo "状态码: $http_code"
                echo "响应头:"
                echo "$headers"
                echo "================"
                echo ""
            } >> "$LOG_FILE"
        fi
```

- [ ] **Step 2: 提交**

```bash
git add http-probe.sh
git commit -m "feat: 添加日志文件和非200响应记录"
```

---

### Task 4: 信号处理 + 最终统计

**Files:**
- Modify: `http-probe.sh`

- [ ] **Step 1: 添加信号处理和最终统计函数**

在 `main()` 函数的 `LOG_FILE` 初始化之后、`declare -A status_counts` 之前，添加：

```bash
    print_final_summary() {
        echo ""
        echo "=== 最终统计 ==="
        print_stats
        echo "=== 统计结束 ==="

        {
            echo ""
            echo "=== 最终统计 ==="
            print_stats
            echo "=== 统计结束 ==="
        } >> "$LOG_FILE"
    }

    trap print_final_summary EXIT
```

- [ ] **Step 2: 提交**

```bash
git add http-probe.sh
git commit -m "feat: 添加信号处理和最终统计输出"
```

---

### Task 5: 本地验证测试

**Files:**
- Create: `test-http-probe.sh`

- [ ] **Step 1: 创建测试脚本**

```bash
#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

assert_contains() {
    local output="$1"
    local expected="$2"
    local test_name="$3"
    if echo "$output" | grep -q "$expected"; then
        echo "PASS: $test_name"
        PASS=$((PASS + 1))
    else
        echo "FAIL: $test_name (expected '$expected' in output)"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== 测试 1: 无参数报错 ==="
output=$(./http-probe.sh 2>&1 || true)
assert_contains "$output" "用法" "无参数打印用法"

echo ""
echo "=== 测试 2: 无效 interval 报错 ==="
output=$(./http-probe.sh "http://example.com" -i abc 2>&1 || true)
assert_contains "$output" "错误" "无效interval报错"

echo ""
echo "=== 测试 3: 无效 count 报错 ==="
output=$(./http-probe.sh "http://example.com" -c abc 2>&1 || true)
assert_contains "$output" "错误" "无效count报错"

echo ""
echo "=== 测试 4: 可达URL探测 ==="
output=$(timeout 10 ./http-probe.sh "http://example.com" -i 0 -c 2 2>&1 || true)
assert_contains "$output" "[200]" "状态码200计数"
assert_contains "$output" "total: 2" "总计数为2"

echo ""
echo "=== 测试 5: 日志文件创建 ==="
log_file=$(ls probe-results-*.log 2>/dev/null | head -1)
if [[ -n "$log_file" ]]; then
    echo "PASS: 日志文件存在"
    PASS=$((PASS + 1))
    rm -f "$log_file"
else
    echo "FAIL: 日志文件不存在"
    FAIL=$((FAIL + 1))
fi

echo ""
echo "=== 结果: $PASS 通过, $FAIL 失败 ==="
[[ "$FAIL" -eq 0 ]] || exit 1
```

- [ ] **Step 2: 运行测试**

```bash
chmod +x test-http-probe.sh
./test-http-probe.sh
```

期望输出：所有测试 PASS。

- [ ] **Step 3: 提交**

```bash
git add test-http-probe.sh http-probe.sh
git commit -m "test: 添加本地验证测试"
```

---

### Task 6: 创建 CLAUDE.md

**Files:**
- Create: `CLAUDE.md`

- [ ] **Step 1: 创建项目说明文件**

```markdown
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

HTTP 探测脚本，按可配置间隔/次数探测单个 HTTP URL，统计状态码，记录非 200 响应。

## 常用命令

- 运行探测: `./http-probe.sh <URL> [-i <interval>] [-c <count>]`
- 运行测试: `./test-http-probe.sh`
- 日志文件: `probe-results-YYYYMMDD-HHMMSS.log` 在当前目录自动生成
```

- [ ] **Step 2: 提交**

```bash
git add CLAUDE.md
git commit -m "docs: 添加 CLAUDE.md 项目说明"
```
