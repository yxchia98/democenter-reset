#!/usr/bin/env bash
set -euo pipefail

echo "WARNING: This will DELETE Ollama images/models and Docker images/containers/volumes/networks/cache."

############################################
# OLLAMA RESET: images, models, data
############################################
echo "==> Resetting Ollama..."

# Stop Ollama service if running (Linux systemd)
if command -v systemctl >/dev/null 2>&1; then
  if systemctl is-active --quiet ollama; then
    echo "Stopping ollama service (systemd)..."
    sudo systemctl stop ollama || true
  fi
fi

# macOS launchctl service name (if applicable)
if [[ "$(uname -s)" == "Darwin" ]]; then
  if launchctl list | grep -q "ollama"; then
    echo "Unloading ollama LaunchDaemon/Agent..."
    # These may fail harmlessly if not present, hence || true
    sudo launchctl unload /Library/LaunchDaemons/com.ollama.ollama.plist 2>/dev/null || true
    launchctl unload ~/Library/LaunchAgents/com.ollama.ollama.plist 2>/dev/null || true
  fi
fi

# Use ollama CLI to delete known models, if available
if command -v ollama >/dev/null 2>&1; then
  echo "Deleting Ollama models via CLI..."
  # List all models and delete them one by one
  ollama list | awk 'NR>1 {print $1}' | while read -r MODEL; do
    if [[ -n "$MODEL" ]]; then
      echo "  - Removing model: $MODEL"
      ollama rm "$MODEL" || true
    fi
  done
else
  echo "ollama CLI not found; skipping CLI-based model removal."
fi

# Remove Ollama data directories (adjust if your install differs)
echo "Removing Ollama data directories..."
sudo rm -rf /usr/share/ollama 2>/dev/null || true
sudo rm -rf /var/lib/ollama 2>/dev/null || true

# Common user directories
rm -rf "$HOME/.ollama" 2>/dev/null || true
rm -rf "$HOME/Library/Application Support/Ollama" 2>/dev/null || true
rm -rf "$HOME/Library/Containers/com.ollama.ollama" 2>/dev/null || true

echo "Ollama reset complete."

############################################
# DOCKER RESET: images, cache, volumes, network
############################################
echo "==> Resetting Docker..."

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker CLI not found; skipping Docker reset."
else
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

  echo "Pruning system (dangling + unused)..."
  docker system prune -af --volumes

  echo "Docker reset complete."
fi

echo "All done. Ollama and Docker have been reset to a clean state."
