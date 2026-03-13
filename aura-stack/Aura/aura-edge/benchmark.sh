#!/bin/bash

# Start Aura Edge in background
./aura-edge/zig-out/bin/aura_edge > aura_edge.log 2>&1 &
EDGE_PID=$!

echo "🚀 Aura Edge Benchmark: First Sweep"
echo "PID: $EDGE_PID"
sleep 2

# 1. Test Regular Request
echo -e "\n--- Test 1: Standard Request ---"
curl -i http://localhost:8080 | grep "HTTP/1.1 200 OK"

# 2. Test DDoS Protection (Rate Limit)
echo -e "\n--- Test 2: Simulating 150 requests (Limit is 100) ---"
for i in {1..110}; do
    curl -s http://localhost:8080 > /dev/null
    if [ $? -ne 0 ]; then echo "Failed at $i"; break; fi
done

echo "Final check (should be 429):"
curl -i http://localhost:8080 | grep "429 Too Many Requests"

# 3. Kill the server
kill $EDGE_PID
echo -e "\n✅ Benchmark Complete. Results in aura_edge.log"
rm aura_edge.log
