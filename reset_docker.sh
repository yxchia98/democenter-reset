#!/usr/bin/env bash
set -euo pipefail

echo "WARNING: This will DELETE all Docker containers, images, volumes, networks, and cache."
read -rp "Type 'RESET' to continue: " CONFIRM
if [[ "${CONFIRM:-}" != "RESET" ]]; then
  echo "Aborting."
  exit 1
fi

############################################
# DOCKER RESET: images, cache, volumes, network
############################################
echo "==> Resetting Docker..."

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker CLI not found; skipping Docker reset."
  exit 0
fi

echo "Stopping all running containers..."
docker ps -q | xargs -r docker stop

echo "Removing all containers..."
docker ps -aq | xargs -r docker rm -f

echo "Removing all images..."
docker images -aq | xargs -r docker rmi -f

echo "Removing all volumes..."
docker volume ls -q | xargs -r docker volume rm -f

echo "Removing all user-defined networks..."
# Keep default bridge, host, none
docker network ls --format '{{.Name}}' | \
  grep -Ev '^(bridge|host|none)$' | \
  xargs -r docker network rm

echo "Pruning build cache..."
docker builder prune -af

echo "Pruning system (dangling + unused, including volumes)..."
docker system prune -af --volumes

echo "Docker reset complete."
