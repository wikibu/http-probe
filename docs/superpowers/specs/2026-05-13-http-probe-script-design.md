---
name: http-probe-script
description: Shell 脚本用于探测单个 HTTP 端点，按可配置间隔/次数请求，统计 HTTP 状态码，并记录非 200 响应
metadata:
  type: project
---

# HTTP 探测脚本设计

## 概述

一个 Shell 脚本，按可配置间隔探测单个 HTTP 端点，跟踪 HTTP 状态码计数，并记录非 200 响应以便排查。

## 接口

```
./http-probe.sh <URL> [-i <interval>] [-c <count>]
```

- `URL`（必填）：目标地址
- `-i interval`：请求间隔（秒），默认 `1`
- `-c count`：探测次数，默认 `0`（无限，直到 Ctrl+C）
- `-h`：打印帮助信息

## 行为

1. 校验 URL 参数，缺失或无效时打印用法并退出
2. 使用 bash 关联数组初始化状态码计数器
3. 创建日志文件：当前目录下的 `probe-results-YYYYMMDD-HHMMSS.log`
4. 循环：发送 `curl -s -w "%{http_code}" -o response_body.tmp` 请求，捕获状态码和响应体，计数器递增
5. 每次请求后，打印更新后的计数到屏幕（例如 `[200] 3 | [404] 1 | total: 4`）
6. 非 200 时：打印时间戳、请求 URL、响应头（通过 `-D -`）和响应体到屏幕，追加到日志文件
7. Ctrl+C 时：通过 `trap SIGINT` 捕获，打印最终统计到屏幕和日志文件，干净退出
8. 达到指定次数时：打印最终统计并退出

## 错误处理

- 通过 `--max-time 30` 设置 curl 超时 30 秒
- 如果 curl 完全失败（DNS、连接拒绝等），记录为 `000` 状态码
- 无效参数打印用法并退出码 1
