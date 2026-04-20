#!/usr/bin/env bash
set -euo pipefail

SITE_NAME="wazuh-soc"
PORT="8443"
HOST="localhost"
TIMEOUT="10"

usage() {
  cat <<'EOF'
Ubuntu health-check for Wazuh SOC Dashboard (read-only checks)

Usage:
  ./scripts/check-ubuntu-wazuh-dashboard.sh [options]

Options:
  --site-name <name>   Nginx site name (default: wazuh-soc-dashboard)
  --port <port>        Dashboard HTTPS port (default: 8443)
  --host <host>        Hostname/IP to test (default: localhost)
  --timeout <sec>      Curl timeout seconds (default: 10)
  -h, --help           Show this help

Checks performed:
  1) nginx site file exists and is enabled
  2) nginx config passes validation
  3) dashboard endpoint responds
  4) proxied /api endpoint responds
  5) proxied /opensearch endpoint responds

Exit code:
  0 when all checks pass, non-zero otherwise.
EOF
}

log() { printf "[INFO] %s\n" "$*"; }
ok() { printf "[OK] %s\n" "$*"; }
warn() { printf "[WARN] %s\n" "$*"; }
fail() { printf "[FAIL] %s\n" "$*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --site-name)
      SITE_NAME="$2"; shift 2 ;;
    --port)
      PORT="$2"; shift 2 ;;
    --host)
      HOST="$2"; shift 2 ;;
    --timeout)
      TIMEOUT="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      fail "Unknown option: $1"
      usage
      exit 1 ;;
  esac
done

SITE_FILE="/etc/nginx/sites-available/${SITE_NAME}"
ENABLED_FILE="/etc/nginx/sites-enabled/${SITE_NAME}"
BASE_URL="https://${HOST}:${PORT}"
FAILED=0

run_check() {
  local desc="$1"
  shift
  if "$@"; then
    ok "$desc"
  else
    fail "$desc"
    FAILED=1
  fi
}

check_file_exists() {
  local path="$1"
  [[ -f "$path" ]]
}

check_enabled_exists() {
  [[ -e "$ENABLED_FILE" ]]
}

check_nginx_config() {
  sudo nginx -t >/dev/null 2>&1
}

check_http_path() {
  local path="$1"
  local code
  code="$(curl -k -sS -o /dev/null -m "$TIMEOUT" -w "%{http_code}" "${BASE_URL}${path}" || true)"
  [[ "$code" =~ ^2|3|401|403$ ]]
}

log "Running health checks for ${BASE_URL} (site: ${SITE_NAME})"

run_check "Nginx site file exists (${SITE_FILE})" check_file_exists "$SITE_FILE"
run_check "Nginx site is enabled (${ENABLED_FILE})" check_enabled_exists
run_check "Nginx config is valid" check_nginx_config
run_check "Dashboard endpoint reachable (${BASE_URL}/)" check_http_path "/"
run_check "Proxied Wazuh API reachable (${BASE_URL}/api/)" check_http_path "/api/"
run_check "Proxied OpenSearch reachable (${BASE_URL}/opensearch/)" check_http_path "/opensearch/"

if [[ "$FAILED" -ne 0 ]]; then
  warn "One or more checks failed."
  warn "If this is a fresh install, verify cert paths, nginx site config, and that Wazuh services are running."
  exit 1
fi

ok "All checks passed."
