#!/bin/bash

# Script to measure and compare startup times between regular and distroless Docker images
# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Spring Boot Startup Time Comparison Tool${NC}"
echo "=============================================="

# Configuration
CONTAINER_NAME_REGULAR="spring-demo-regular"
CONTAINER_NAME_DISTROLESS="spring-demo-distroless"
IMAGE_NAME_REGULAR="spring-demo:regular"
IMAGE_NAME_DISTROLESS="spring-demo:distroless"
PORT=8080
TEST_RUNS=3
HEALTH_ENDPOINT="/health"

# Functions
cleanup() {
    echo -e "${YELLOW}Cleaning up containers...${NC}"
    docker stop $CONTAINER_NAME_REGULAR $CONTAINER_NAME_DISTROLESS 2>/dev/null || true
    docker rm $CONTAINER_NAME_REGULAR $CONTAINER_NAME_DISTROLESS 2>/dev/null || true
}

build_images() {
    echo -e "${BLUE}Building Docker images...${NC}"
    
    # Build regular image
    echo -e "${YELLOW}Building regular OpenJDK image...${NC}"
    docker build -t $IMAGE_NAME_REGULAR -f Dockerfile .
    
    # Build distroless image
    echo -e "${YELLOW}Building distroless image...${NC}"
    docker build -t $IMAGE_NAME_DISTROLESS -f Dockerfile.distroless .
    
    echo -e "${GREEN}Images built successfully!${NC}"
}

wait_for_app() {
    local port=$1
    local container_name=$2
    local max_wait=60
    local count=0
    
    echo -e "${YELLOW}Waiting for application to start on port $port...${NC}"
    
    while [ $count -lt $max_wait ]; do
        if curl -s http://localhost:$port$HEALTH_ENDPOINT > /dev/null 2>&1; then
            echo -e "${GREEN}Application is ready!${NC}"
            return 0
        fi
        sleep 1
        count=$((count + 1))
    done
    
    echo -e "${RED}Application failed to start within $max_wait seconds${NC}"
    return 1
}

measure_startup_time() {
    local image_name=$1
    local container_name=$2
    local port=$3
    local run_number=$4
    
    echo -e "${BLUE}Testing $image_name (Run $run_number)${NC}"
    
    # Start timing
    start_time=$(date +%s%N)
    
    # Start container
    docker run -d --name $container_name -p $port:8080 $image_name
    
    # Wait for application to be ready
    if wait_for_app $port $container_name; then
        end_time=$(date +%s%N)
        startup_time=$(( (end_time - start_time) / 1000000 )) # Convert to milliseconds
        echo -e "${GREEN}Startup time: ${startup_time}ms${NC}"
        
        # Get container logs for additional timing info
        echo -e "${YELLOW}Application logs:${NC}"
        docker logs $container_name | grep -E "(Started|Application started|ready)"
        
        echo "$startup_time"
    else
        echo -e "${RED}Failed to start container${NC}"
        docker logs $container_name
        echo "FAILED"
    fi
    
    # Cleanup
    docker stop $container_name >/dev/null 2>&1
    docker rm $container_name >/dev/null 2>&1
}

compare_images() {
    echo -e "${BLUE}Comparing image sizes...${NC}"
    
    regular_size=$(docker images $IMAGE_NAME_REGULAR --format "table {{.Size}}" | tail -n 1)
    distroless_size=$(docker images $IMAGE_NAME_DISTROLESS --format "table {{.Size}}" | tail -n 1)
    
    echo -e "Regular image size: ${YELLOW}$regular_size${NC}"
    echo -e "Distroless image size: ${YELLOW}$distroless_size${NC}"
    echo ""
    
    echo -e "${BLUE}Starting performance comparison...${NC}"
    echo ""
    
    # Arrays to store results
    regular_times=()
    distroless_times=()
    
    # Test regular image
    echo -e "${BLUE}Testing Regular OpenJDK Image${NC}"
    echo "================================"
    for i in $(seq 1 $TEST_RUNS); do
        result=$(measure_startup_time $IMAGE_NAME_REGULAR "${CONTAINER_NAME_REGULAR}-$i" $((PORT + i)) $i)
        if [ "$result" != "FAILED" ]; then
            regular_times+=($result)
        fi
        echo ""
        sleep 2
    done
    
    # Test distroless image
    echo -e "${BLUE}Testing Distroless Image${NC}"
    echo "========================"
    for i in $(seq 1 $TEST_RUNS); do
        result=$(measure_startup_time $IMAGE_NAME_DISTROLESS "${CONTAINER_NAME_DISTROLESS}-$i" $((PORT + 10 + i)) $i)
        if [ "$result" != "FAILED" ]; then
            distroless_times+=($result)
        fi
        echo ""
        sleep 2
    done
    
    # Calculate averages
    if [ ${#regular_times[@]} -gt 0 ]; then
        regular_avg=$(( $(IFS=+; echo "$((${regular_times[*]}))") / ${#regular_times[@]} ))
    else
        regular_avg="N/A"
    fi
    
    if [ ${#distroless_times[@]} -gt 0 ]; then
        distroless_avg=$(( $(IFS=+; echo "$((${distroless_times[*]}))") / ${#distroless_times[@]} ))
    else
        distroless_avg="N/A"
    fi
    
    # Display results
    echo -e "${GREEN}Results Summary${NC}"
    echo "==============="
    echo -e "Regular OpenJDK:"
    echo -e "  Image size: ${YELLOW}$regular_size${NC}"
    echo -e "  Times: ${YELLOW}${regular_times[*]}${NC} ms"
    echo -e "  Average: ${YELLOW}${regular_avg}${NC} ms"
    echo ""
    echo -e "Distroless:"
    echo -e "  Image size: ${YELLOW}$distroless_size${NC}"
    echo -e "  Times: ${YELLOW}${distroless_times[*]}${NC} ms"
    echo -e "  Average: ${YELLOW}${distroless_avg}${NC} ms"
    echo ""
    
    if [ "$regular_avg" != "N/A" ] && [ "$distroless_avg" != "N/A" ]; then
        improvement=$(( regular_avg - distroless_avg ))
        percentage=$(( improvement * 100 / regular_avg ))
        echo -e "Improvement: ${GREEN}${improvement}ms (${percentage}%)${NC}"
    fi
}

# Main execution
echo -e "${YELLOW}Checking Docker availability...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker is not installed or not in PATH${NC}"
    exit 1
fi

# Trap to ensure cleanup on script exit
trap cleanup EXIT

# Check if Maven wrapper exists
if [ ! -f "./mvnw" ]; then
    echo -e "${YELLOW}Maven wrapper not found. Creating it...${NC}"
    mvn -N wrapper:wrapper
fi

# Build application first
echo -e "${YELLOW}Building Spring Boot application...${NC}"
./mvnw clean package -DskipTests

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to build Spring Boot application${NC}"
    exit 1
fi

# Menu
echo ""
echo "Select operation:"
echo "1. Build images only"
echo "2. Compare startup times only (requires pre-built images)"
echo "3. Build images and compare startup times"
echo "4. Cleanup containers and images"
echo ""
read -p "Enter your choice (1-4): " choice

case $choice in
    1)
        build_images
        ;;
    2)
        compare_images
        ;;
    3)
        build_images
        echo ""
        compare_images
        ;;
    4)
        cleanup
        echo -e "${YELLOW}Removing images...${NC}"
        docker rmi $IMAGE_NAME_REGULAR $IMAGE_NAME_DISTROLESS 2>/dev/null || true
        echo -e "${GREEN}Cleanup complete!${NC}"
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}Script completed!${NC}"