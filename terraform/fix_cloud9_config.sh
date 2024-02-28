#!/bin/bash

AWS_REGION=$(curl -H "X-aws-ec2-metadata-token:${TOKEN}" -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/\(.*\)[a-z]/\1/')

# Export EKS config to kubeconfig file
aws eks --region "$AWS_REGION" update-kubeconfig --name eks-saas-gitops
mkdir /home/ec2-user/.kube && cp /root/.kube/config /home/ec2-user/.kube/ && chown -R ec2-user:ec2-user /home/ec2-user/.kube/config

# Removing Helm files that are not reconciled
helm uninstall metrics-server -nkube-system --kubeconfig /root/.kube/config
helm uninstall kubecost -nkubecost --kubeconfig /root/.kube/config
helm uninstall karpenter -nkarpenter --kubeconfig /root/.kube/config

# Reconciling again
flux reconcile helmrelease metrics-server -nflux-system --kubeconfig /root/.kube/config
flux reconcile helmrelease kubecost -nflux-system --kubeconfig /root/.kube/config
flux reconcile helmrelease karpenter -nflux-system --kubeconfig /root/.kube/config

# Get cfn parameter from ssm created by Lambda function
CFN_PARAMETER="$(aws ssm get-parameter --name "eks-saas-gitops-custom-resource-event" --query "Parameter.Value" --output text)" 

#set variables
STATUS="SUCCESS"
EVENT_STACK_ID=$(echo "$CFN_PARAMETER" | jq -r .StackId)
EVENT_REQUEST_ID=$(echo "$CFN_PARAMETER" | jq -r .RequestId)
EVENT_LOGICAL_RESOURCE_ID=$(echo "$CFN_PARAMETER" | jq -r .LogicalResourceId)
EVENT_RESPONSE_URL=$(echo "$CFN_PARAMETER" | jq -r .ResponseURL)

JSON_DATA='{
     "Status": "'"$STATUS"'",
     "Reason": "Terraform executed successfully from Cloud9",
     "StackId": "'"$EVENT_STACK_ID"'",
     "PhysicalResourceId": "Terraform",
     "RequestId": "'"$EVENT_REQUEST_ID"'",
     "LogicalResourceId": "'"$EVENT_LOGICAL_RESOURCE_ID"'"
}'

# Send the JSON data using curl
curl -X PUT --data-binary "$JSON_DATA" "$EVENT_RESPONSE_URL"