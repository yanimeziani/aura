#!/bin/bash
# Test script for World State Map Delta Engine

API_URL="http://localhost:9000"

echo "1. Fetching initial world state..."
curl -s "$API_URL/world/state" | jq .

echo -e "\n2. Starting SSE stream in background..."
curl -s "$API_URL/world/stream" > world_stream.log &
STREAM_PID=$!

sleep 2

echo "3. Updating region owner (Region 1 -> World Leaders)..."
curl -s -X POST "$API_URL/world/update" \
     -H "Content-Type: application/json" \
     -d '{"region_id":"region_1", "owner_id":"world_leaders"}' | jq .

sleep 2

echo "4. Checking SSE log for delta..."
cat world_stream.log

kill $STREAM_PID
rm world_stream.log

echo -e "\n5. Final world state check..."
curl -s "$API_URL/world/state" | jq .
