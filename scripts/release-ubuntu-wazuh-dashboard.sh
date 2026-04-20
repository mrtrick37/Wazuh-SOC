#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
INSTALL_SCRIPT="${SCRIPT_DIR}/install-ubuntu-wazuh-dashboard.sh"
UPDATE_SCRIPT="${SCRIPT_DIR}/update-ubuntu-wazuh-dashboard.sh"
CHECK_SCRIPT="${SCRIPT_DIR}/check-ubuntu-wazuh-dashboard.sh"

SITE_NAME="wazuh-soc"
PROJECT_DIR="${DEFAULT_PROJECT_DIR}"
WEB_ROOT="/var/www/wazuh-soc"
PORT="8443"
HOST="localhost"
CERT_PATH="/etc/wazuh-dashboard/certs/dashboard.pem"
KEY_PATH="/etc/wazuh-dashboard/certs/dashboard-key.pem"
SKIP_DEPS="false"
SKIP_BUILD="false"
SKIP_CHECK="false"
NON_INTERACTIVE="false"
FORCE_INSTALL="false"

usage() {
  cat <<'EOF'
Ubuntu release wrapper for Wazuh SOC Dashboard

Usage:
  ./scripts/release-ubuntu-wazuh-dashboard.sh [options]

Behavior:
  - If nginx site is not present/enabled -> runs installer
  - If nginx site exists and enabled     -> runs updater
  - Then runs health check (unless --skip-check)

Options:
  --project-dir <path>   Project directory containing package.json and dist/. (default: script parent)
  --site-name <name>     Nginx site filename (default: wazuh-soc-dashboard)
  --web-root <path>      Static deployment path (default: /var/www/wazuh-soc-dashboard)
  --port <port>          Dashboard HTTPS port (default: 8443)
  --host <host>          Host/IP for health-check URL tests (default: localhost)
  --cert <path>          TLS cert path (used during install path)
  --key <path>           TLS key path (used during install path)
  --skip-deps            Skip apt/node/nginx dependency install (installer only)
  --skip-build           Skip npm build and deploy existing dist/
  --skip-check           Skip post-release health-check
  --non-interactive      Pass non-interactive mode to child scripts
  --force-install        Force installer path even if site already exists
  -h, --help             Show this help
EOF
}

log() { printf "[INFO] %s\n" "$*"; }
err() { printf "[ERROR] %s\n" "$*" >&2; }

require_script() {
  local script="$1"
  if [[ ! -f "$script" ]]; then
    err "Missing required script: $script"
    exit 1
  fi
  chmod +x "$script"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-dir)
      PROJECT_DIR="$2"; shift 2 ;;
    --site-name)
      SITE_NAME="$2"; shift 2 ;;
    --web-root)
      WEB_ROOT="$2"; shift 2 ;;
    --port)
      PORT="$2"; shift 2 ;;
    --host)
      HOST="$2"; shift 2 ;;
    --cert)
      CERT_PATH="$2"; shift 2 ;;
    --key)
      KEY_PATH="$2"; shift 2 ;;
    --skip-deps)
      SKIP_DEPS="true"; shift ;;
    --skip-build)
      SKIP_BUILD="true"; shift ;;
    --skip-check)
      SKIP_CHECK="true"; shift ;;
    --non-interactive)
      NON_INTERACTIVE="true"; shift ;;
    --force-install)
      FORCE_INSTALL="true"; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      err "Unknown option: $1"
      usage
      exit 1 ;;
  esac
done

if [[ ! -d "$PROJECT_DIR" ]]; then
  err "Project directory does not exist: $PROJECT_DIR"
  exit 1
fi

require_script "$INSTALL_SCRIPT"
require_script "$UPDATE_SCRIPT"
require_script "$CHECK_SCRIPT"

SITE_FILE="/etc/nginx/sites-available/${SITE_NAME}"
ENABLED_FILE="/etc/nginx/sites-enabled/${SITE_NAME}"

run_install() {
  local args=()
  args+=(--project-dir "$PROJECT_DIR")
  args+=(--site-name "$SITE_NAME")
  args+=(--web-root "$WEB_ROOT")
  args+=(--port "$PORT")
  args+=(--cert "$CERT_PATH")
  args+=(--key "$KEY_PATH")
  [[ "$SKIP_DEPS" == "true" ]] && args+=(--skip-deps)
  [[ "$SKIP_BUILD" == "true" ]] && args+=(--skip-build)
  [[ "$NON_INTERACTIVE" == "true" ]] && args+=(--non-interactive)

  log "Running installer path..."
  "$INSTALL_SCRIPT" "${args[@]}"
}

run_update() {
  local args=()
  args+=(--project-dir "$PROJECT_DIR")
  args+=(--site-name "$SITE_NAME")
  args+=(--web-root "$WEB_ROOT")
  [[ "$SKIP_BUILD" == "true" ]] && args+=(--skip-build)
  [[ "$NON_INTERACTIVE" == "true" ]] && args+=(--non-interactive)

  log "Running updater path..."
  "$UPDATE_SCRIPT" "${args[@]}"
}

run_check() {
  local args=()
  args+=(--site-name "$SITE_NAME")
  args+=(--port "$PORT")
  args+=(--host "$HOST")

  log "Running post-release health check..."
  "$CHECK_SCRIPT" "${args[@]}"
}

log "Release configuration:"
printf "  Project dir:   %s\n" "$PROJECT_DIR"
printf "  Site name:     %s\n" "$SITE_NAME"
printf "  Web root:      %s\n" "$WEB_ROOT"
printf "  Port:          %s\n" "$PORT"
printf "  Host(check):   %s\n" "$HOST"
printf "  Skip deps:     %s\n" "$SKIP_DEPS"
printf "  Skip build:    %s\n" "$SKIP_BUILD"
printf "  Skip check:    %s\n" "$SKIP_CHECK"
printf "  Force install: %s\n" "$FORCE_INSTALL"

if [[ "$FORCE_INSTALL" == "true" ]]; then
  run_install
elif [[ -f "$SITE_FILE" && -e "$ENABLED_FILE" ]]; then
  run_update
else
  run_install
fi

if [[ "$SKIP_CHECK" != "true" ]]; then
  run_check
fi

log "Release flow completed successfully."
