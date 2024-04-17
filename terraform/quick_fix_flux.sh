#!/bin/bash

# Set the namespace
namespace="flux-system"

# Fetch the list of failed Helm releases using kubectl, filtering for "False" status
readarray -t failed_releases < <(kubectl get helmrelease -n $namespace | grep -i 'False' | awk '{print $1}')

# Check if there are any failed releases to process
if [ ${#failed_releases[@]} -eq 0 ]; then
    echo "No failed Helm releases found in the $namespace namespace."
else
    # Loop through the failed Helm releases and delete them using flux
    echo "Deleting failed Helm releases in the $namespace namespace..."
    for release in "${failed_releases[@]}"; do
        echo "Deleting Helm release $release in namespace $namespace..."
        flux delete helmrelease $release -n $namespace --silent
    done

    # Optionally, reconcile the source after deleting the failed releases
    echo "Reconciling source git 'flux-system' in the $namespace namespace..."
    flux reconcile source git flux-system -n $namespace

    echo "Operation completed."
fi

# It will fail if secret is already there
kubectl create secret generic github-ssh-key --from-file=ssh-privatekey=/home/ec2-user/environment/flux --from-literal=ssh-privatekey.mode=0600 -nargo-workflows
