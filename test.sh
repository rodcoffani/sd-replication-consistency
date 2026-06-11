#!/usr/bin/env bash
set -e

echo "========================================"
echo " Test 1: 20 increments on node1"
echo "========================================"

for i in $(seq 1 20); do
  curl -s -X POST http://localhost:5001/increment > /dev/null
done

echo ""
echo "--- Checking /value at different intervals ---"

for delay in 0 1 2 5 10; do
  sleep $delay
  echo ""
  echo "--- After ${delay}s ---"
  for port in 5001 5002 5003; do
    curl -s http://localhost:$port/value
    echo ""
  done
done

echo ""
echo "========================================"
echo " Test 2: node2 goes offline"
echo "========================================"

docker compose stop node2

echo ""
echo "--- Incrementing 10 times on node1 ---"
for i in $(seq 1 10); do
  curl -s -X POST http://localhost:5001/increment > /dev/null
done

sleep 14

echo ""
echo "--- Values after replication window (node2 was offline) ---"
for port in 5001 5002 5003; do
  hash=$(curl -s http://localhost:$port/value || echo 'offline')
  echo "node${port: -1}: $hash"
done

echo ""
echo "--- Starting node2 back ---"
docker compose start node2
sleep 2

echo ""
echo "--- Final values (node2 is stale) ---"
for port in 5001 5002 5003; do
  hash=$(curl -s http://localhost:$port/value)
  echo "node${port: -1}: $hash"
done

echo ""
echo "========================================"
echo " Test 3: strong vs weak consistency"
echo "========================================"

docker compose restart
sleep 3

echo ""
echo "--- Stopping node2 (it will miss everything) ---"
docker compose stop node2

echo ""
echo "--- 15 increments on node1 ---"
for i in $(seq 1 15); do
  curl -s -X POST http://localhost:5001/increment > /dev/null
done

echo ""
echo "--- Wait for replication window ---"
sleep 14

echo ""
echo "--- Start node2 (fresh, counter=0) ---"
docker compose start node2
sleep 1

echo ""
echo "--- [WEAK] node2 returns its local stale value ---"
curl -s http://localhost:5002/value
echo ""

echo ""
echo "--- [STRONG] node2 consults peers, returns latest from node1 ---"
curl -s "http://localhost:5002/value?consistency=strong"
echo ""

echo ""
echo "--- For reference: node1 and node3 values ---"
curl -s http://localhost:5001/value
echo ""
curl -s http://localhost:5003/value
echo ""
