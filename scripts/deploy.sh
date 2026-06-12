#!/usr/bin/env bash
# deploy.sh — pull new image and restart container on target EC2 instance
# Called by cd.yml:  bash scripts/deploy.sh <environment> <image>
#
# Expects these env vars to be set by the workflow:
#   DEPLOY_HOST  — EC2 public IP or hostname
#   DEPLOY_KEY   — SSH private key content (from secrets)

set -euo pipefail

ENVIRONMENT="${1:?Usage: deploy.sh <environment> <image>}"
IMAGE="${2:?Usage: deploy.sh <environment> <image>}"

echo "Deploying $IMAGE to $ENVIRONMENT ($DEPLOY_HOST)..."

# Write SSH key to a temp file
KEY_FILE=$(mktemp)
chmod 600 "$KEY_FILE"
echo "$DEPLOY_KEY" > "$KEY_FILE"
trap 'rm -f "$KEY_FILE"' EXIT

SSH="ssh -i $KEY_FILE -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$DEPLOY_HOST"

# Pull latest image and restart the container
$SSH bash -s "$IMAGE" "$ENVIRONMENT" <<'REMOTE'
  IMAGE="$1"
  ENV="$2"
  CONTAINER="app-${ENV}"
  PORT=3000

  echo "Pulling $IMAGE..."
  aws ecr get-login-password --region "${AWS_REGION:-us-east-1}" \
    | docker login --username AWS --password-stdin "$(echo $IMAGE | cut -d/ -f1)"
  docker pull "$IMAGE"

  echo "Stopping old container (if any)..."
  docker stop "$CONTAINER" 2>/dev/null || true
  docker rm   "$CONTAINER" 2>/dev/null || true

  echo "Starting new container..."
  docker run -d \
    --name "$CONTAINER" \
    --restart unless-stopped \
    -p "${PORT}:3000" \
    -e NODE_ENV="$ENV" \
    "$IMAGE"

  echo "Container started: $(docker ps --filter name=$CONTAINER --format '{{.Status}}')"
REMOTE

echo "Deploy to $ENVIRONMENT complete."
