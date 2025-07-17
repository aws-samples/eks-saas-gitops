#!/bin/bash

# Script to continuously monitor tenant microservices
# This script dynamically discovers tenants from Flux Helm releases
# and monitors their producer and consumer endpoints

# Colors for better visibility
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
BG_GREEN='\033[42m'
NC='\033[0m' # No Color

# Function to get the current timestamp
get_timestamp() {
  date "+%Y-%m-%d %H:%M:%S"
}

# Function to determine if environment is siloed or pooled
get_deployment_type() {
  local env=$1
  if [[ $env == pool-* ]]; then
    echo -e "${PURPLE}POOLED${NC}"
  else
    echo -e "${CYAN}SILOED${NC}"
  fi
}

# Function to format version output with change detection
format_version() {
  local current_version=$1
  local previous_version=$2
  
  if [ "$previous_version" != "" ] && [ "$current_version" != "$previous_version" ]; then
    echo -e "${BOLD}${BG_GREEN}$current_version${NC} (changed from $previous_version)"
  else
    echo -e "$current_version"
  fi
}

# Function to discover tenants from Flux Helm releases
discover_tenants() {
  local helm_releases=$(flux get helmreleases -A)
  
  # Extract tenant IDs from Helm releases
  # First, get all lines with tenant- in them
  local tenant_lines=$(echo "$helm_releases" | grep "tenant-")
  
  # Extract the tenant IDs (tenant-1, tenant-2, etc.) from these lines
  local tenant_ids=""
  while read -r line; do
    if [[ $line =~ tenant-([0-9]+) ]]; then
      tenant_ids="$tenant_ids tenant-${BASH_REMATCH[1]}"
    fi
  done <<< "$tenant_lines"
  
  # Remove duplicates and sort
  local unique_tenants=$(echo "$tenant_ids" | tr ' ' '\n' | sort -u | tr '\n' ' ')
  
  # If no tenants found, use default set
  if [ -z "$unique_tenants" ]; then
    echo "tenant-1 tenant-2 tenant-3 tenant-4"
  else
    echo "$unique_tenants"
  fi
}

# Function to get tenant tier from Flux Helm releases
get_tenant_info() {
  local tenant=$1
  local helm_releases=$2
  
  # Look for tenant entries in helm releases that match the pattern tenant-X-tier
  # For example: tenant-4-premium
  local tenant_line=$(echo "$helm_releases" | grep -E "$tenant-[a-z]+" | head -1)
  
  if [ -n "$tenant_line" ]; then
    # Extract tier directly from the pattern tenant-X-tier
    # For example: tenant-4-premium -> premium
    if [[ $tenant_line =~ $tenant-([a-z]+) ]]; then
      local tier="${BASH_REMATCH[1]}"
    else
      local tier="unknown"
    fi
    
    # Extract chart version
    local chart_version=$(echo "$tenant_line" | grep -o 'helm-tenant-chart@[0-9.]*' | cut -d '@' -f2)
    if [ -z "$chart_version" ]; then
      chart_version="unknown"
    fi
    
    # Extract namespace from the release info
    if [[ $tenant_line =~ release[[:space:]]+([^/]+)/ ]]; then
      local namespace="${BASH_REMATCH[1]}"
    else
      local namespace="unknown"
    fi
    
    echo "$tier|$chart_version|$namespace"
  else
    # Check if it's in a pool
    local pool_line=$(echo "$helm_releases" | grep "pool-" | grep "$tenant" | head -1)
    if [ -n "$pool_line" ]; then
      # Extract tier from pool line
      if [[ $pool_line =~ $tenant-([a-z]+) ]]; then
        local tier="${BASH_REMATCH[1]}"
      else
        local tier="unknown"
      fi
      
      # Extract chart version
      local chart_version=$(echo "$pool_line" | grep -o 'helm-tenant-chart@[0-9.]*' | cut -d '@' -f2)
      if [ -z "$chart_version" ]; then
        chart_version="unknown"
      fi
      
      # Extract namespace from the release info
      if [[ $pool_line =~ release[[:space:]]+([^/]+)/ ]]; then
        local namespace="${BASH_REMATCH[1]}"
      else
        local namespace="unknown"
      fi
      
      echo "$tier|$chart_version|$namespace"
    else
      echo "unknown|unknown|unknown"
    fi
  fi
}

# Initialize version tracking arrays
declare -A producer_versions
declare -A consumer_versions

clear
echo "Starting tenant microservices monitoring..."
echo "Press Ctrl+C to stop monitoring"
echo "----------------------------------------"

# Main monitoring loop
while true; do
  # Get all Helm releases for this iteration
  HELM_RELEASES=$(flux get helmreleases -A)
  
  # Discover tenants dynamically
  TENANTS=$(discover_tenants)
  
  # Get the Application Load Balancer hostname
  # Try to get it from any tenant namespace
  APP_LB=""
  for tenant in $TENANTS; do
    APP_LB=$(kubectl get ingress -n $tenant -o json 2>/dev/null | jq -r '.items[0].status.loadBalancer.ingress[0].hostname' 2>/dev/null)
    if [ -n "$APP_LB" ] && [ "$APP_LB" != "null" ]; then
      break
    fi
  done
  
  # If we couldn't get the ALB from any tenant, try the first tenant as fallback
  if [ -z "$APP_LB" ] || [ "$APP_LB" == "null" ]; then
    APP_LB=$(kubectl get ingress -n tenant-1 -o json 2>/dev/null | jq -r '.items[0].status.loadBalancer.ingress[0].hostname' 2>/dev/null)
  fi
  
  if [ -z "$APP_LB" ] || [ "$APP_LB" == "null" ]; then
    echo -e "${RED}[$(get_timestamp)] Error: Could not get ALB hostname. Make sure the ingress is properly configured.${NC}"
    sleep 5
    continue
  fi
  
  APP_LB="http://$APP_LB"
  
  echo -e "${BLUE}[$(get_timestamp)] Monitoring ALB: $APP_LB${NC}"
  echo -e "${BLUE}[$(get_timestamp)] Discovered tenants: $TENANTS${NC}"
  
  # Loop through all discovered tenants
  for tenant in $TENANTS; do
    echo -e "${YELLOW}[$(get_timestamp)] Checking $tenant...${NC}"
    
    # Get tenant information from Flux Helm releases
    tenant_info=$(get_tenant_info "$tenant" "$HELM_RELEASES")
    tier=$(echo "$tenant_info" | cut -d '|' -f1)
    chart_version=$(echo "$tenant_info" | cut -d '|' -f2)
    namespace=$(echo "$tenant_info" | cut -d '|' -f3)
    
    # Request producer endpoint
    producer_response=$(curl -s -H "tenantID: $tenant" $APP_LB/producer)
    producer_env=$(echo $producer_response | jq -r '.environment // "unknown"')
    producer_version=$(echo $producer_response | jq -r '.version // "unknown"')
    producer_deployment_type=$(get_deployment_type "$producer_env")
    
    # Request consumer endpoint
    consumer_response=$(curl -s -H "tenantID: $tenant" $APP_LB/consumer)
    consumer_env=$(echo $consumer_response | jq -r '.environment // "unknown"')
    consumer_version=$(echo $consumer_response | jq -r '.version // "unknown"')
    consumer_deployment_type=$(get_deployment_type "$consumer_env")
    
    # Format versions with change detection
    producer_version_formatted=$(format_version "$producer_version" "${producer_versions[$tenant]}")
    consumer_version_formatted=$(format_version "$consumer_version" "${consumer_versions[$tenant]}")
    
    # Store current versions for next comparison
    producer_versions[$tenant]=$producer_version
    consumer_versions[$tenant]=$consumer_version
    
    # Display results with tenant tier information
    echo -e "${GREEN}$tenant ($tier tier):${NC} Chart: $chart_version | Namespace: $namespace"
    echo -e "  Producer: Version: $producer_version_formatted | Environment: $producer_env | Type: $producer_deployment_type"
    echo -e "  Consumer: Version: $consumer_version_formatted | Environment: $consumer_env | Type: $consumer_deployment_type"
    echo "----------------------------------------"
  done
  
  # Wait before next iteration
  sleep 5
  echo -e "${BLUE}[$(get_timestamp)] Refreshing...${NC}"
  echo "========================================"
done
