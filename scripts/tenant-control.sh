#!/bin/bash

task=$1
tenant_tier=$2
tenant_id=$3

# check if argument is one of the alloweds.
if [[ ! $task =~ ^(onboarding|offboarding|deployment)$ ]]; then
  echo "Usage: $0 <onboarding|offboarding|deployment>"
fi

queue_url=$(aws sqs list-queues --queue-name-prefix argoworkflows-"$task" | jq .QueueUrls[0])

onboarding_msg="{'tenant_id': '$tenant_id', 'tenant_tier': '${tenant_tier}', 'release_version': '0.0'}"
offboarding_msg="{'tenant_id': '$tenant_id', 'tenant_tier': '${tenant_tier}', 'release_version': '0.0'}"
deployment_msg="{'tenant_id': '$tenant_id', 'tenant_tier': '${tenant_tier}', 'release_version': '0.0'}"

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

aws sqs send-message --queue-url "$queue_url" --message-body "$msg"

# Get Argo Workflow URL
ARGO_WORKFLOW_URL=$(kubectl -n argo-workflows get service/argo-workflows-server -o json | jq -r '.status.loadBalancer.ingress[0].hostname')
echo "Argo Workflow URL: http://$ARGO_WORKFLOW_URL:2746/workflows"
