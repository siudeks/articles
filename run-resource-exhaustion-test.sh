#!/bin/bash

# Script to run resource exhaustion tests with limited system resources

echo "Setting resource limits for testing..."

# Set maximum number of open file descriptors to a low value
ulimit -n 1024

# Set maximum number of processes
ulimit -u 512

# Show current limits
echo "Current resource limits:"
echo "Max open files: $(ulimit -n)"
echo "Max processes: $(ulimit -u)"
echo "Max memory (kbytes): $(ulimit -m)"

echo ""
echo "Running resource exhaustion tests..."

# Run only the ResourceExhaustionTest
mvn test -Dtest=ResourceExhaustionTest -Dmaven.test.failure.ignore=false

echo ""
echo "Test execution completed."