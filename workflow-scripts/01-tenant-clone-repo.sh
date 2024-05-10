#!/bin/bash

if [ -z "$1" ]; then
  echo "Please provide the repo_url as the first argument."
  exit 1
fi

REPOSITORY_URL="$1"
REPOSITORY_BRANCH="$2"

git clone -b $REPOSITORY_BRANCH "$REPOSITORY_URL"