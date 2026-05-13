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
