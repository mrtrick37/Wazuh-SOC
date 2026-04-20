#!/usr/bin/env bash
set -euo pipefail

# Auto-detect nginx site name, web root, and port
NGINX_SITES_AVAILABLE="/etc/nginx/sites-available"
NGINX_SITES_ENABLED="/etc/nginx/sites-enabled"

# Find the first enabled site that listens on 8443 (or any port), ignoring .bak files
SITE_FILE=$(find "$NGINX_SITES_AVAILABLE" -type f ! -name '*.bak*' -exec grep -l 'listen[[:space:]]\+[0-9]\+.*ssl;' {} + | head -n1)
if [ -z "$SITE_FILE" ]; then
  echo "[ERROR] Could not auto-detect nginx site file. Please specify manually."
  exit 1
fi
SITE_NAME=$(basename "$SITE_FILE")

# Extract web root from the site file
WEB_ROOT=$(grep -E 'root[[:space:]]+' "$SITE_FILE" | head -n1 | awk '{print $2}' | sed 's/;//')
if [ -z "$WEB_ROOT" ]; then
  echo "[ERROR] Could not auto-detect web root from $SITE_FILE. Please specify manually."
  exit 1
fi

# Extract port (default to 8443 if not found)
PORT=$(grep -Eo 'listen[[:space:]]+[0-9]+' "$SITE_FILE" | head -n1 | awk '{print $2}')
PORT=${PORT:-8443}

echo "Detected site: $SITE_NAME"
echo "Detected web root: $WEB_ROOT"
echo "Detected port: $PORT"

# Remove existing nginx site
if [ -f "$NGINX_SITES_ENABLED/$SITE_NAME" ]; then
  sudo rm -f "$NGINX_SITES_ENABLED/$SITE_NAME"
fi
if [ -f "$NGINX_SITES_AVAILABLE/$SITE_NAME" ]; then
  sudo rm -f "$NGINX_SITES_AVAILABLE/$SITE_NAME"
fi

# Remove web root (optional, comment out if you want to keep existing files)
sudo rm -rf "$WEB_ROOT"

sudo systemctl reload nginx




# Install dependencies (Node.js, nginx, rsync)
echo "[INFO] Installing Node.js, nginx, and other dependencies..."
sudo apt-get update
sudo apt-get install -y nodejs nginx rsync

# Ensure npm is available (Node.js 22.x bundles npm, but check)
if ! command -v npm >/dev/null 2>&1; then
  echo "[INFO] npm not found, installing npm globally via Node.js..."
  sudo npm install -g npm
else
  echo "[INFO] npm is already installed: $(npm -v)"
fi

# Reload nginx to apply removal
sudo systemctl reload nginx

# Run installer script to recreate everything
SCRIPT_DIR="$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)"
cd "$SCRIPT_DIR/.."

if [ ! -f "./scripts/install-ubuntu-wazuh-dashboard.sh" ]; then
  echo "[ERROR] Installer script not found!"
  exit 1
fi

./scripts/install-ubuntu-wazuh-dashboard.sh --site-name "$SITE_NAME" --web-root "$WEB_ROOT" --port "$PORT"

# Reload nginx again to apply new site
sudo systemctl reload nginx

echo "Reinstallation complete."
