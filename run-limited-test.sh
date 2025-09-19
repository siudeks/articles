#!/bin/bash

# Alternative script using direct Java execution with strict resource limits

echo "Running resource exhaustion test with moderate JVM limits..."

# Set moderate ulimits to force quicker failure but allow Maven to start
ulimit -n 2048   # Moderate file descriptor limit
ulimit -u 1024   # Moderate process limit

echo "Resource limits set:"
echo "Max open files: $(ulimit -n)"
echo "Max processes: $(ulimit -u)"

# Run the test with very restricted JVM settings
mvn test \
  -Dtest=ResourceExhaustionTests \
  -Dmaven.test.failure.ignore=false \
  -Dtest.max.sockets=3000 \
  -Dtest.max.connections=30000 \
  -Djunit.jupiter.execution.timeout.default=30s

echo "Test execution completed."