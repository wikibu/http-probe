---
name: http-probe-script
description: Shell script to probe a URL with configurable interval/count, count HTTP status codes, and log non-200 responses
metadata:
  type: project
---

# HTTP Probe Script Design

## Overview

A shell script that probes a single HTTP endpoint at configurable intervals, tracks HTTP status code counts, and logs non-200 responses for debugging.

## Interface

```
./http-probe.sh <URL> [-i <interval>] [-c <count>]
```

- `URL` (required): target endpoint
- `-i interval`: seconds between requests, default `1`
- `-c count`: number of probes, default `0` (infinite until Ctrl+C)
- `-h`: print usage

## Behavior

1. Validate URL argument, exit with usage if missing or invalid
2. Initialize status code counters using bash associative array
3. Create log file: `probe-results-YYYYMMDD-HHMMSS.log` in current directory
4. Loop: send `curl -s -w "%{http_code}" -o response_body.tmp` to URL, capture status code and body, increment counter
5. After each request, print updated counts to screen (e.g., `[200] 3 | [404] 1 | total: 4`)
6. On non-200: print timestamp, request URL, response headers (via `-D -`), and body to screen, append to log file
7. On Ctrl+C: `trap SIGINT`, print final summary to screen and log file, exit cleanly
8. On count reached: print final summary and exit

## Error Handling

- `curl` timeout set to 30s via `--max-time 30`
- If curl fails entirely (DNS, connection refused), record as `000` status code
- Invalid arguments print usage and exit 1
