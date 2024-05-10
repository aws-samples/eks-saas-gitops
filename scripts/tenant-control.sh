#!/bin/bash

#!/bin/bash

# Function to display usage information
function display_usage() {
  echo "Usage: $0 <task> <tenant_tier> <release_version> <tenant_id>"
  echo -e "\nWhere:"
  echo -e "  <task> can be onboarding, offboarding, deployment, or testing."
  echo -e "  <tenant_tier> is the tenant's tier."
  echo -e "  <release_version> is the version of the release for onboarding, offboarding, or deployment tasks."
  echo -e "  <tenant_id> is the ID of the tenant. For testing task, replace <release_version> with <tenant_id>."
  echo -e "\nExample:"
  echo -e "  $0 onboarding premium 1.0 tenant-123"
  echo -e "  $0 testing basic tenant-456"
  exit 1
}

# Check if no arguments were passed
if [ $# -eq 0 ]; then
  display_usage
fi

task=$1
tenant_tier=$2
release_version=$3
tenant_id=$4

# Check if argument is one of the allowed.
if [[ ! $task =~ ^(onboarding|offboarding|deployment|testing)$ ]]; then
  echo "Invalid task: $task"
  display_usage
fi

if [ "$task" == "testing" ]; then
  if [ $# -ne 3 ]; then # Ensure correct number of arguments for testing
    echo "Testing task requires 3 arguments: task, tenant_tier, and tenant_id."
    display_usage
  fi
  tenant_id=$3 # In this case, is the 3rd argument for testing tenants
else
  if [ $# -ne 4 ]; then # Ensure correct number of arguments for other tasks
    echo "$task task requires 4 arguments: task, tenant_tier, release_version, and tenant_id."
    display_usage
  fi
fi


if [ "$task" == "testing" ]; then
  tenant_id=$3 # In this case is 3 argument for testing tenants

  INGRESS_URL=$(kubectl get ingress -npool-1 | tail -1 | awk '{print $4}')
  curl --location --request POST "http://${INGRESS_URL}/producer" \
  --header "tenantID: $tenant_id" \
  --header "tier: $tenant_tier"
  exit 0 # Exit after printing usage information
fi

queue_url=$(aws sqs list-queues --queue-name-prefix "argoworkflows-$task" --query "QueueUrls[0]" --output text)

# Check if the queue URL was successfully retrieved
if [ -z "$queue_url" ]; then
  echo "Error: Queue URL for task $task not found."
  exit 1
fi

# Use valid JSON format for messages
onboarding_msg="{\"tenant_id\": \"$tenant_id\", \"tenant_tier\": \"$tenant_tier\", \"release_version\": \"$release_version\"}"
offboarding_msg="{\"tenant_id\": \"$tenant_id\", \"tenant_tier\": \"$tenant_tier\", \"release_version\": \"$release_version\"}"
deployment_msg="{\"tenant_tier\": \"$tenant_tier\", \"release_version\": \"$release_version\"}"

case $task in
  onboarding)
    msg=$onboarding_msg
    ;;
  offboarding) 
    msg=$offboarding_msg
    ;;
  deployment)
    msg=$deployment_msg
    ;;
esac

echo "Task: $task, Tenant_id: $tenant_id, Queue: $queue_url, Release: $release_version"

# Ensure that the variable expansions are quoted correctly
aws sqs send-message --queue-url "$queue_url" --message-body "$msg"

# Get Argo Workflow URL
ARGO_WORKFLOW_URL=$(kubectl -n argo-workflows get service/argo-workflows-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Argo Workflow URL: http://$ARGO_WORKFLOW_URL:2746/workflows"
