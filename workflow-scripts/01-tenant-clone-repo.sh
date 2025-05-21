#!/bin/bash

if [ -z "$1" ]; then
  echo "Please provide the repo_url as the first argument."
  exit 1
fi

REPOSITORY_URL="$1"
REPOSITORY_BRANCH="$2"
GIT_USERNAME="$3"
GIT_TOKEN="$4"

# Extract protocol and domain from URL
PROTOCOL_AND_DOMAIN=$(echo $REPOSITORY_URL | grep -o "^[^/]*//[^/]*")

# Create URL with authentication
AUTH_URL="${PROTOCOL_AND_DOMAIN/\/\//\/\/$GIT_USERNAME:$GIT_TOKEN@}$(echo $REPOSITORY_URL | sed "s|^[^/]*//[^/]*||")"

git clone -b $REPOSITORY_BRANCH "$AUTH_URL"