#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEFAULT_BACKEND_SETUP_SCRIPT="$(cd "${SCRIPT_DIR}/../backend" && pwd)/setup-production.sh"

SITE_NAME="wazuh-soc"
WEB_ROOT="/var/www/wazuh-soc"
PROJECT_DIR="${DEFAULT_PROJECT_DIR}"
BACKEND_SETUP_SCRIPT="${DEFAULT_BACKEND_SETUP_SCRIPT}"
SKIP_BUILD="false"
SKIP_GIT_PULL="false"
NON_INTERACTIVE="false"

usage() {
  cat <<'EOF'
Ubuntu updater for Wazuh SOC Dashboard (safe, isolated update)

Usage:
  ./scripts/update-ubuntu-wazuh-dashboard.sh [options]

Options:
  --project-dir <path>   Project directory containing package.json and dist/. (default: script parent)
  --site-name <name>     Nginx site filename (default: wazuh-soc-dashboard).
  --web-root <path>      Static deployment path (default: /var/www/wazuh-soc-dashboard).
  --skip-git-pull        Skip git fetch/pull before build/deploy.
  --skip-build           Skip npm install + npm run build and deploy existing dist/.
  --non-interactive      Do not prompt for confirmation.
  -h, --help             Show this help.

What this script does:
  1) Builds updated frontend assets (unless --skip-build)
  2) Syncs dist/ to the existing web root
  3) Reconciles backend service and nginx admin proxy
  4) Validates nginx config and reloads nginx

What this script does NOT do:
  - It does not install apt packages.
  - It does not alter Wazuh manager/indexer configs.
  - It does not replace default Wazuh components.
EOF
}

log() { printf "[INFO] %s\n" "$*"; }
err() { printf "[ERROR] %s\n" "$*" >&2; }

run_sudo() {
  if [[ "$NON_INTERACTIVE" == "true" ]]; then
    if ! sudo -n /usr/bin/systemctl --version > /dev/null 2>&1; then
      err "Passwordless sudo is required for non-interactive update actions."
      err "Run ./backend/setup-production.sh once interactively to install the sudoers policy, then retry."
      exit 1
    fi
    sudo -n "$@"
    return
  fi

  sudo "$@"
}

confirm() {
  local prompt="$1"
  if [[ "$NON_INTERACTIVE" == "true" ]]; then
    return 0
  fi
  read -r -p "$prompt [y/N]: " answer
  [[ "$answer" =~ ^[Yy]$ ]]
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    err "Required command not found: $1"
    exit 1
  fi
}

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
    --skip-git-pull)
      SKIP_GIT_PULL="true"; shift ;;
    --skip-build)
      SKIP_BUILD="true"; shift ;;
    --non-interactive)
      NON_INTERACTIVE="true"; shift ;;
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

if [[ ! -f "$PROJECT_DIR/package.json" ]]; then
  err "package.json not found in project directory: $PROJECT_DIR"
  exit 1
fi

SITE_FILE="/etc/nginx/sites-available/${SITE_NAME}"
ENABLED_FILE="/etc/nginx/sites-enabled/${SITE_NAME}"

if [[ ! -f "$SITE_FILE" ]]; then
  err "Expected nginx site file not found: $SITE_FILE"
  err "Run installer first or pass the correct --site-name."
  exit 1
fi

if [[ ! -e "$ENABLED_FILE" ]]; then
  err "Expected enabled nginx site not found: $ENABLED_FILE"
  err "Enable the site first or pass the correct --site-name."
  exit 1
fi

require_cmd sudo
require_cmd rsync
require_cmd nginx
require_cmd node
require_cmd npm
require_script "$BACKEND_SETUP_SCRIPT"

if [[ "$SKIP_GIT_PULL" != "true" && -d "$PROJECT_DIR/.git" ]]; then
  require_cmd git
fi

log "Updater configuration:"
printf "  Project dir: %s\n" "$PROJECT_DIR"
printf "  Site name:   %s\n" "$SITE_NAME"
printf "  Site file:   %s\n" "$SITE_FILE"
printf "  Web root:    %s\n" "$WEB_ROOT"
printf "  Skip pull:   %s\n" "$SKIP_GIT_PULL"
printf "  Skip build:  %s\n" "$SKIP_BUILD"

if ! confirm "Proceed with update?"; then
  log "Cancelled by user."
  exit 0
fi

if [[ "$SKIP_GIT_PULL" != "true" ]]; then
  if [[ -d "$PROJECT_DIR/.git" ]]; then
    log "Updating repository in $PROJECT_DIR ..."
    git -C "$PROJECT_DIR" fetch --all --prune
    git -C "$PROJECT_DIR" pull --ff-only
  else
    log "Skipping git pull: $PROJECT_DIR is not a git repository."
  fi
fi

if [[ "$SKIP_BUILD" != "true" ]]; then
  log "Building updated dashboard in $PROJECT_DIR ..."
  pushd "$PROJECT_DIR" >/dev/null
  npm install --include=dev
  npm run build
  popd >/dev/null
fi

if [[ ! -d "$PROJECT_DIR/dist" ]]; then
  err "dist/ folder not found at $PROJECT_DIR/dist. Build failed or --skip-build used incorrectly."
  exit 1
fi

log "Syncing static assets to $WEB_ROOT ..."
run_sudo mkdir -p "$WEB_ROOT"
run_sudo rsync -av --delete "$PROJECT_DIR/dist/" "$WEB_ROOT/"
run_sudo chown -R www-data:www-data "$WEB_ROOT"

log "Reconciling backend service and nginx admin proxy ..."
"$BACKEND_SETUP_SCRIPT" --site-file "$SITE_FILE" --non-interactive

log "Validating nginx config ..."
run_sudo nginx -t

log "Reloading nginx ..."
run_sudo systemctl reload nginx

log "Scheduling backend service restart ..."
if command -v systemd-run >/dev/null 2>&1; then
  run_sudo systemd-run --unit "wazuh-soc-backend-restart-$(date +%s)" --on-active=2s /usr/bin/systemctl restart wazuh-soc-backend.service >/dev/null
  log "Backend restart scheduled via systemd-run (2s delay)."
else
  log "systemd-run unavailable, requesting non-blocking backend restart."
  run_sudo systemctl restart --no-block wazuh-soc-backend.service
fi

HOSTNAME_FQDN="$(hostname -f 2>/dev/null || hostname)"

cat <<EOF

Update complete.

Check app:
  https://${HOSTNAME_FQDN}:8443

Update safety:
  - No default Wazuh components were replaced.
  - Only static assets were refreshed at:
      ${WEB_ROOT}
  - Existing nginx site was reused:
      ${SITE_FILE}

Quick verification:
  curl -k https://${HOSTNAME_FQDN}:8443/
  curl -k https://${HOSTNAME_FQDN}:8443/api/
  curl -k https://${HOSTNAME_FQDN}:8443/opensearch/
EOF
