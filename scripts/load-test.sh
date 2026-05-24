#!/bin/bash

# FamPay SRE - Load testing script
# Prerequisites: Install oha (https://github.com/hatoo/oha)
# Usage: ./scripts/load-test.sh [host]

HOST=${1:-http://localhost}

echo "=== FamPay Load Test ==="
echo "Target: ${HOST}"
echo ""

echo "--- Testing /hodr/ endpoint ---"
oha -n 1000 -c 50 --latency-correction "${HOST}/hodr/"

echo ""
echo "--- Testing /bran/ endpoint ---"
oha -n 500 -c 25 --latency-correction "${HOST}/bran/"

echo ""
echo "=== Load Test Complete ==="
echo "Check Grafana at http://localhost:3000 for metrics"
