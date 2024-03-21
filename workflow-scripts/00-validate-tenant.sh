#!/bin/bash

TENANT_ID="$1"
TENANT_TIER="$2"
TENANTS_MANIFEST_PATH="/mnt/vol/eks-saas-gitops/gitops/application-plane/production/tenants/${TENANT_TIER}"
TENANT_FILE_FOUND=false

# Function to search for the tenant file in a given directory
search_for_tenant() {
    local search_path="$1"
    for i in "${search_path}"*; do
        if [[ $i == *"${TENANT_ID}"* ]]; then
            TENANT_FILE_FOUND=true
            return
        fi
    done
}

# Search in the defined directories
search_for_tenant "$TENANTS_MANIFEST_PATH"

if $TENANT_FILE_FOUND; then
    echo "Tenant '${TENANT_ID}' already exists."
    exit 1
else
    echo "Tenant '${TENANT_ID}' does not exist, proceed"
fi