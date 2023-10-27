

if [ -z "$1" ]; then
  echo "Please provide the repo_url as the first argument."
  exit 1
fi

# Assign the tenant_id and tenant_model arguments to variables
REPOSITORY_URL="$1"
REPOSITORY_BRANCH="$2"

git clone -b $REPOSITORY_BRANCH "$REPOSITORY_URL"