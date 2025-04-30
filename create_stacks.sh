#!/usr/bin/env bash

PORTAINER_URL=${PORTAINER_URL:?"Please set the PORTAINER_URL environment variable."}
PORTAINER_API_KEY=${PORTAINER_API_KEY:?"Please set the PORTAINER_API_KEY environment variable."}
PORTAINER_ENVIRONMENT_ID=${PORTAINER_ENVIRONMENT_ID:?"Please set the PORTAINER_ENVIRONMENT_ID environment variable."}

for compose_path in */compose.yaml; do
    stack_name=$(dirname "$compose_path")

    echo "Processing stack: $stack_name ($compose_path)"

    read -r -d '' payload <<EOF
{
  "name": "$stack_name",
  "composeFile": "$compose_path",
  "repositoryURL": "https://github.com/s3lcsum/gitops",
  "repositoryReferenceName": "refs/heads/main",
  "autoUpdate": {
    "forcePullImage": false,
    "forceUpdate": false,
    "interval": "5m"
  }
}
EOF

    curl -s \
        -H "X-API-Key: $PORTAINER_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$PORTAINER_URL/api/stacks/create/standalone/repository?endpointId=${PORTAINER_ENVIRONMENT_ID}" | jq
done

echo "All stacks processed."
