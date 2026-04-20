#!/usr/bin/env bash
set -euo pipefail

# Defaults
SITE_NAME="wazuh-soc"
WEB_ROOT="/var/www/wazuh-soc"
PORT=8443
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_SETUP_SCRIPT="$PROJECT_DIR/backend/setup-production.sh"

usage() {
  cat <<EOF
Wazuh SOC Dashboard Installer

Options:
  --site-name <name>     Nginx site name (default: $SITE_NAME)
  --web-root <path>      Web root for static files (default: $WEB_ROOT)
  --port <port>          HTTPS port for nginx (default: $PORT)
  -h, --help             Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --site-name)
      SITE_NAME="$2"; shift 2 ;;
    --web-root)
      WEB_ROOT="$2"; shift 2 ;;
    --port)
      PORT="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

log() { echo -e "\033[1;34m[INFO]\033[0m $*"; }
err() { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }

# Detect existing installation
EXISTING_INSTALL=false
EXISTING_MARKERS=()
[ -f "/etc/nginx/sites-available/$SITE_NAME" ] && { EXISTING_INSTALL=true; EXISTING_MARKERS+=("nginx site config: /etc/nginx/sites-available/$SITE_NAME"); }
[ -d "$WEB_ROOT" ] && { EXISTING_INSTALL=true; EXISTING_MARKERS+=("web root: $WEB_ROOT"); }
systemctl list-unit-files wazuh-soc-backend.service &>/dev/null && systemctl list-unit-files wazuh-soc-backend.service | grep -q wazuh-soc-backend && { EXISTING_INSTALL=true; EXISTING_MARKERS+=("systemd service: wazuh-soc-backend.service"); }

if [ "$EXISTING_INSTALL" = true ]; then
  warn "An existing installation was detected:"
  for marker in "${EXISTING_MARKERS[@]}"; do
    warn "  - $marker"
  done
  echo ""
  read -r -p "An existing install was found. Overwrite it? [y/N] " CONFIRM
  case "$CONFIRM" in
    [yY][eE][sS]|[yY]) log "Proceeding with installation over existing install..." ;;
    *) log "Aborting."; exit 0 ;;
  esac
  echo ""
fi

# 1. Install dependencies
sudo apt-get update
log "Installing Node.js, nginx, and other dependencies..."
sudo apt-get update
sudo apt-get install -y nodejs nginx rsync

# Ensure npm is available (Node.js 22.x bundles npm, but check)
if ! command -v npm >/dev/null 2>&1; then
  log "npm not found, installing npm globally via Node.js..."
  sudo npm install -g npm
else
  log "npm is already installed: $(npm -v)"
fi

# 2. Build frontend
log "Building frontend..."
cd "$PROJECT_DIR"
npm install --include=dev
npm run build

# 3. Prepare web root
log "Syncing static assets to $WEB_ROOT ..."
sudo mkdir -p "$WEB_ROOT"
sudo rsync -av --delete "$PROJECT_DIR/dist/" "$WEB_ROOT/"
sudo chown -R www-data:www-data "$WEB_ROOT"

# 4. Backend setup
log "Running backend setup script..."
chmod +x "$BACKEND_SETUP_SCRIPT"
"$BACKEND_SETUP_SCRIPT" --site-name "$SITE_NAME" --web-root "$WEB_ROOT" --non-interactive

# 5. Nginx site config
NGINX_SITE_FILE="/etc/nginx/sites-available/$SITE_NAME"
if [ ! -f "$NGINX_SITE_FILE" ]; then
  log "Creating nginx site config at $NGINX_SITE_FILE ..."
  sudo tee "$NGINX_SITE_FILE" > /dev/null <<EOF
server {
    listen $PORT ssl;
    server_name _;
    root $WEB_ROOT;
    index index.html;

    ssl_certificate     /etc/ssl/certs/ssl-cert-snakeoil.pem;
    ssl_certificate_key /etc/ssl/private/ssl-cert-snakeoil.key;

    location / {
        try_files $uri $uri/ /index.html;
    }

    include $PROJECT_DIR/backend/nginx.conf.snippet;
}
EOF
fi

if [ ! -e "/etc/nginx/sites-enabled/$SITE_NAME" ]; then
  sudo ln -s "$NGINX_SITE_FILE" "/etc/nginx/sites-enabled/$SITE_NAME"
fi

log "Testing nginx config..."
sudo nginx -t
log "Reloading nginx..."
sudo systemctl reload nginx

log "Enabling and starting backend service..."
sudo systemctl enable wazuh-soc-backend.service
sudo systemctl restart wazuh-soc-backend.service

log "Installation complete!"
echo "Access the dashboard at: https://<your-server>:$PORT/"
