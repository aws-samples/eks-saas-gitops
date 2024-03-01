#!/bin/bash

# Set the namespace
namespace="flux-system"

# Fetch the list of Helm releases and filter by READY status
# Assuming READY is the 4th column in the flux get helmreleases output
failed_releases=$(flux get helmreleases -n $namespace | awk '$4 == "False" {print $1}')

# Check if there are any failed releases to process
if [ -z "$failed_releases" ]; then
    echo "No failed Helm releases found in the $namespace namespace."
else
    # Loop through the failed Helm releases and delete them
    echo "Deleting failed Helm releases in the $namespace namespace..."
    for release in $failed_releases; do
        echo "Deleting Helm release $release in namespace $namespace..."
        flux delete helmrelease $release -n $namespace --silent
    done

    # Reconcile the source after deleting the failed releases
    echo "Reconciling source git 'flux-system' in the $namespace namespace..."
    flux reconcile source git flux-system -n $namespace

    echo "Operation completed."
fi
