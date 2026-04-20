#!/bin/bash
# Production setup script for Wazuh SOC Dashboard Backend
# Installs systemd service and optionally patches nginx configuration

set -euo pipefail

# Resolve script location regardless of where it's called from
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$SCRIPT_DIR"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
NGINX_SNIPPET="$BACKEND_DIR/nginx.conf.snippet"
SITE_FILE=""
SITE_NAME="wazuh-soc"
WEB_ROOT="/var/www/wazuh-soc"
NON_INTERACTIVE="false"
ALLOW_SERVICE_RESTART="false"
SERVICE_USER="${SUDO_USER:-$(id -un)}"
SUDOERS_FILE="/etc/sudoers.d/wazuh-soc"

usage() {
    cat <<'EOF'
Usage:
    ./backend/setup-production.sh [options]

Options:
    --site-file <path>     Existing nginx site file to patch with backend proxy blocks.
    --site-name <name>     Nginx site name to autodetect (default: wazuh-soc).
    --web-root <path>      Web root to use for nginx autodetection (default: /var/www/wazuh-soc).
    --non-interactive      Suppress prompts.
    --allow-service-restart Allow backend service restart in non-interactive mode.
    -h, --help             Show this help.
EOF
}

confirm() {
    local prompt="$1"
    if [[ "$NON_INTERACTIVE" == "true" ]]; then
        return 0
    fi
    read -r -p "$prompt [y/N]: " answer
    [[ "$answer" =~ ^[Yy]$ ]]
}

run_sudo() {
    if [[ "$NON_INTERACTIVE" == "true" ]]; then
        if ! sudo -n /usr/bin/systemctl --version > /dev/null 2>&1; then
            echo "[ERROR] Passwordless sudo is required for non-interactive deployment actions." >&2
            echo "[ERROR] Run this script once interactively to install the sudoers policy, then retry the GUI update." >&2
            exit 1
        fi
        sudo -n "$@"
        return
    fi

    sudo "$@"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --site-file)
            SITE_FILE="$2"
            shift 2
            ;;
        --site-name)
            SITE_NAME="$2"
            shift 2
            ;;
        --web-root)
            WEB_ROOT="$2"
            shift 2
            ;;
        --non-interactive)
            NON_INTERACTIVE="true"
            shift
            ;;
        --allow-service-restart)
            ALLOW_SERVICE_RESTART="true"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            exit 1
            ;;
    esac
done

detect_site_file() {
    local candidate
    local first_match

    candidate="/etc/nginx/sites-available/${SITE_NAME}"
    if [[ -f "$candidate" ]]; then
        SITE_FILE="$candidate"
        return 0
    fi

    candidate="/etc/nginx/sites-enabled/${SITE_NAME}"
    if [[ -f "$candidate" ]]; then
        SITE_FILE="$candidate"
        return 0
    fi

    first_match="$({ grep -R -l -E "root[[:space:]]+${WEB_ROOT}[[:space:]]*;|listen[[:space:]]+8443[[:space:]]+ssl;" /etc/nginx/sites-available 2>/dev/null || true; } | head -n 1)"
    if [[ -n "$first_match" && -f "$first_match" ]]; then
        SITE_FILE="$first_match"
        return 0
    fi

    return 1
}

install_sudoers_policy() {
    local temp_file
    local mkdir_bin rsync_bin chown_bin cp_bin ln_bin rm_bin tee_bin chmod_bin systemctl_bin systemd_run_bin journalctl_bin nginx_bin visudo_bin

    mkdir_bin="$(command -v mkdir)"
    rsync_bin="$(command -v rsync)"
    chown_bin="$(command -v chown)"
    cp_bin="$(command -v cp)"
    ln_bin="$(command -v ln)"
    rm_bin="$(command -v rm)"
    tee_bin="$(command -v tee)"
    chmod_bin="$(command -v chmod)"
    systemctl_bin="$(command -v systemctl)"
    systemd_run_bin="$(command -v systemd-run || echo /usr/bin/systemd-run)"
    journalctl_bin="$(command -v journalctl)"
    nginx_bin="$(command -v nginx)"
    visudo_bin="$(command -v visudo || true)"

    temp_file="$(mktemp)"

    cat > "$temp_file" <<EOF
Defaults:${SERVICE_USER} !requiretty
${SERVICE_USER} ALL=(root) NOPASSWD: ${mkdir_bin}, ${rsync_bin}, ${chown_bin}, ${cp_bin}, ${ln_bin}, ${rm_bin}, ${tee_bin}, ${chmod_bin}, ${systemctl_bin}, ${systemd_run_bin}, ${journalctl_bin}, ${nginx_bin}
EOF

    if [[ -n "$visudo_bin" ]]; then
        "$visudo_bin" -cf "$temp_file" >/dev/null
    fi

    run_sudo cp "$temp_file" "$SUDOERS_FILE"
    run_sudo chmod 440 "$SUDOERS_FILE"
    rm -f "$temp_file"

    echo "✓ Installed sudoers policy for ${SERVICE_USER}: $SUDOERS_FILE"
}

ensure_nginx_proxy() {
    local target_file="$1"
    local temp_file
    local backup_file

    if [[ -z "$target_file" || ! -f "$target_file" ]]; then
        return 0
    fi

    temp_file="$(mktemp)"
    backup_file="${target_file}.bak.$(date +%Y%m%d%H%M%S)"

    awk '
        function print_admin_blocks() {
            print "    location /api/admin/ {"
            print "        proxy_pass http://127.0.0.1:3001;"
            print "        proxy_http_version 1.1;"
            print "        proxy_set_header Upgrade $http_upgrade;"
            print "        proxy_set_header Connection \"upgrade\";"
            print "        proxy_set_header Host $host;"
            print "        proxy_set_header X-Real-IP $remote_addr;"
            print "        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;"
            print "        proxy_set_header X-Forwarded-Proto $scheme;"
            print "        proxy_connect_timeout 60s;"
            print "        proxy_send_timeout 300s;"
            print "        proxy_read_timeout 300s;"
            print "    }"
            print ""
            print "    location = /health {"
            print "        proxy_pass http://127.0.0.1:3001/health;"
            print "        access_log off;"
            print "    }"
            print ""
            inserted=1
        }
        /location \/api\/admin\// {
            skip=1
            next
        }
        /location = \/health/ {
            skip=1
            next
        }
        skip {
            if ($0 ~ /^[[:space:]]*}/) {
                skip=0
            }
            next
        }
        /location \/api\// && !inserted {
            print_admin_blocks()
        }
        { print }
    ' "$target_file" > "$temp_file"

    run_sudo cp "$target_file" "$backup_file"
    run_sudo cp "$temp_file" "$target_file"
    rm -f "$temp_file"

    echo "✓ Patched nginx site file: $target_file"
    echo "✓ Backup created: $backup_file"
}

echo "=========================================="
echo "Wazuh SOC Backend Setup"
echo "=========================================="

# 1. Verify backend is built
echo ""
echo "[1] Building backend..."
cd "$BACKEND_DIR"
npm install --include=dev
npm run build
echo "✓ Backend built successfully"

# 2. Install passwordless sudo policy for service user
echo ""
echo "[2] Installing sudoers policy..."
install_sudoers_policy

# 3. Generate and install systemd service with correct paths
echo ""
echo "[3] Installing systemd service..."
NODE_BIN="$(which node)"
SERVICE_PATH="${PATH:-/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin}"

# Write service file with correct resolved paths
cat > /tmp/wazuh-soc-backend.service << EOF
[Unit]
Description=Wazuh SOC Backend
After=network.target

[Service]
Type=simple
User=${SERVICE_USER}
WorkingDirectory=${BACKEND_DIR}
ExecStart=${NODE_BIN} ${BACKEND_DIR}/dist/server.js
Restart=on-failure
RestartSec=10
Environment="NODE_ENV=production"
Environment="PORT=3001"
Environment="PATH=${SERVICE_PATH}"

StandardOutput=journal
StandardError=journal
SyslogIdentifier=wazuh-soc-backend

[Install]
WantedBy=multi-user.target
EOF

run_sudo cp /tmp/wazuh-soc-backend.service /etc/systemd/system/wazuh-soc-backend.service
run_sudo systemctl daemon-reload
echo "✓ Systemd service installed (paths: $BACKEND_DIR)"

# 4. Configure Nginx
echo ""
echo "[4] Configuring nginx proxy..."
if [[ -z "$SITE_FILE" ]]; then
    detect_site_file || true
fi

if [[ -n "$SITE_FILE" ]]; then
    echo "Using nginx site file: $SITE_FILE"
    ensure_nginx_proxy "$SITE_FILE"
    echo "✓ Nginx proxy configuration reconciled"
else
    echo "No --site-file provided. Current proxy snippet:"
    echo ""
    cat "$NGINX_SNIPPET"
    echo ""
    if ! confirm "Continue without patching nginx automatically?"; then
        exit 1
    fi
fi

# 5. Enable and start service
echo "[5] Enabling and starting backend service..."
run_sudo systemctl enable wazuh-soc-backend.service
if [[ "$NON_INTERACTIVE" == "true" && "$ALLOW_SERVICE_RESTART" != "true" ]]; then
    echo "✓ Backend service enabled (skipping restart — called from within the running service)"
else
    run_sudo systemctl restart --no-block wazuh-soc-backend.service
    echo "✓ Backend service enabled and started"
fi

# 6. Verify service is running
echo ""
echo "[6] Verifying service status..."
if run_sudo systemctl is-active --quiet wazuh-soc-backend.service; then
    echo "✓ Backend service is running"
    
    # Give it a moment to start
    sleep 2
    
    # Check health
    if curl -s http://localhost:3001/health | grep -q "ok"; then
        echo "✓ Backend health check passed"
    else
        echo "✗ Health check failed - backend may not be responding"
    fi
else
    echo "✗ Backend service failed to start"
    run_sudo journalctl -u wazuh-soc-backend.service -n 20
    exit 1
fi

if [[ -n "$SITE_FILE" ]]; then
    echo ""
    echo "[7] Validating and reloading nginx..."
    run_sudo nginx -t
    run_sudo systemctl reload nginx
    echo "✓ Nginx reloaded"
fi

echo ""
echo "=========================================="
echo "Setup complete!"
echo "=========================================="
echo ""
echo "Service management:"
echo "  Start:   sudo systemctl start wazuh-soc-backend"
echo "  Stop:    sudo systemctl stop wazuh-soc-backend"
echo "  Status:  sudo systemctl status wazuh-soc-backend"
echo "  Logs:    sudo journalctl -u wazuh-soc-backend -f"
echo ""
