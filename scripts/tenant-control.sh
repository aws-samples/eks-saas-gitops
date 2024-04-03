#!/bin/bash

task=$1
tenant_tier=$2
tenant_id=$3
release_version=$4

# Check if argument is one of the allowed.
if [[ ! $task =~ ^(onboarding|offboarding|deployment)$ ]]; then
  echo "Usage: $0 <onboarding|offboarding|deployment>"
  exit 1 # Exit after printing usage information
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

echo "Task: $task, Tenant_id: $tenant_id, Queue: $queue_url"

# Ensure that the variable expansions are quoted correctly
aws sqs send-message --queue-url "$queue_url" --message-body "$msg"

# Get Argo Workflow URL
ARGO_WORKFLOW_URL=$(kubectl -n argo-workflows get service/argo-workflows-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Argo Workflow URL: http://$ARGO_WORKFLOW_URL:2746/workflows"
