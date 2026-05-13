# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

HTTP 探测脚本，按可配置间隔/次数探测单个 HTTP URL，统计状态码，记录非 200 响应。

## 常用命令

- 运行探测: `./http-probe.sh <URL> [-i <interval>] [-c <count>]`
- 运行测试: `./test-http-probe.sh`
- 日志文件: `probe-results-YYYYMMDD-HHMMSS.log` 在当前目录自动生成
