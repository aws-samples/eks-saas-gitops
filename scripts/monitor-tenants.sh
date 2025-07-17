#!/bin/bash

# Script to continuously monitor tenant microservices
# This script will make requests to both producer and consumer endpoints
# for tenant-1, tenant-2, tenant-3, and tenant-4

# Colors for better visibility
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to get the current timestamp
get_timestamp() {
  date "+%Y-%m-%d %H:%M:%S"
}

echo "Starting tenant microservices monitoring..."
echo "Press Ctrl+C to stop monitoring"
echo "----------------------------------------"

# Main monitoring loop
while true; do
  # Get the Application Load Balancer hostname
  # We'll use tenant-1 to get the ALB, as all tenants should use the same ALB
  APP_LB=$(kubectl get ingress -n tenant-1 -o json | jq -r '.items[0].status.loadBalancer.ingress[0].hostname')
  
  if [ -z "$APP_LB" ] || [ "$APP_LB" == "null" ]; then
    echo -e "${RED}[$(get_timestamp)] Error: Could not get ALB hostname. Make sure the ingress is properly configured.${NC}"
    sleep 5
    continue
  fi
  
  APP_LB="http://$APP_LB"
  
  echo -e "${BLUE}[$(get_timestamp)] Monitoring ALB: $APP_LB${NC}"
  
  # Loop through all tenants
  for tenant in tenant-1 tenant-2 tenant-3 tenant-4; do
    echo -e "${YELLOW}[$(get_timestamp)] Checking $tenant...${NC}"
    
    # Request producer endpoint
    producer_response=$(curl -s -H "tenantID: $tenant" $APP_LB/producer)
    producer_version=$(echo $producer_response | jq -r '.version // "unknown"')
    producer_message=$(echo $producer_response | jq -r '.message // "No message"')
    
    # Request consumer endpoint
    consumer_response=$(curl -s -H "tenantID: $tenant" $APP_LB/consumer)
    consumer_version=$(echo $consumer_response | jq -r '.version // "unknown"')
    consumer_message=$(echo $consumer_response | jq -r '.message // "No message"')
    
    # Display results
    echo -e "${GREEN}$tenant Producer:${NC} Version: $producer_version - Message: $producer_message"
    echo -e "${GREEN}$tenant Consumer:${NC} Version: $consumer_version - Message: $consumer_message"
    echo "----------------------------------------"
  done
  
  # Wait before next iteration
  sleep 5
  echo -e "${BLUE}[$(get_timestamp)] Refreshing...${NC}"
  echo "========================================"
done
