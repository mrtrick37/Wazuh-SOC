# Wazuh SOC
This project is a QRadar-style SOC interface built on top of Wazuh and OpenSearch.
For deployment and backend operations, use the backend guide as the single source of truth:
- backend/README.md
- backend/setup-production.sh
- backend/nginx.conf.snippet
- backend/wazuh-soc-backend.service
1. Initial install
- scripts/install-ubuntu-wazuh-dashboard.sh
- Installs deps (optional), builds, deploys static files, configures isolated nginx site.
2. Safe update
- scripts/update-ubuntu-wazuh-dashboard.sh
- Rebuilds and redeploys static assets, validates and reloads nginx.
3. Read-only health check
- scripts/check-ubuntu-wazuh-dashboard.sh
- Verifies site wiring and endpoint reachability.
4. One-command release wrapper
- scripts/release-ubuntu-wazuh-dashboard.sh
- Auto-selects install vs update, then runs health checks.
Set this first to the raw script URL in your repository:
	export INSTALLER_URL="https://raw.githubusercontent.com/mrtrick37/Wazuh-SOC/main/scripts/install-ubuntu-wazuh-dashboard.sh"
Curl (auto-clones source to $HOME/wazuh-soc if needed):

	curl -fsSL "$INSTALLER_URL" -o /tmp/install-ubuntu-wazuh-dashboard.sh && bash /tmp/install-ubuntu-wazuh-dashboard.sh

Wget (auto-clones source to $HOME/wazuh-soc if needed):

	wget -qO /tmp/install-ubuntu-wazuh-dashboard.sh "$INSTALLER_URL" && bash /tmp/install-ubuntu-wazuh-dashboard.sh

Override clone target/repo ref explicitly:

	curl -fsSL "$INSTALLER_URL" -o /tmp/install-ubuntu-wazuh-dashboard.sh && bash /tmp/install-ubuntu-wazuh-dashboard.sh --clone-dir "$HOME/wazuh-soc" --repo-ref main

Recommended for repeatable deployments (pin a commit):

	export INSTALLER_URL="https://raw.githubusercontent.com/mrtrick37/Wazuh-SOC/<commit-sha>/scripts/install-ubuntu-wazuh-dashboard.sh"
	curl -fsSL "$INSTALLER_URL" -o /tmp/install-ubuntu-wazuh-dashboard.sh && bash /tmp/install-ubuntu-wazuh-dashboard.sh --repo-ref <commit-sha> --non-interactive
# Wazuh SOC Dashboard

This project is a QRadar-style SOC interface built on top of Wazuh and OpenSearch.

Its core goal is simple: turn raw Wazuh alert data into an analyst-friendly workflow for triage, investigation, and queue management, while keeping deployment safe and isolated from default Wazuh components.

## What This Project Is Doing

The application provides a dark-mode operations console with five primary analyst workflows:

1. Security Overview (Dashboard)
- Shows live agent posture from Wazuh manager data.
- Shows live OpenSearch alert trend data.
- Shows live recent alerts for fast triage context.
- Shows live open offense count.

2. Agent Operations
- Displays inventory of Wazuh agents with status and metadata.
- Supports filtering and sorting for operational hygiene and drift checks.

3. Offense Queue (QRadar-like)
- Synthesizes offenses by grouping events with key = rule id x agent id.
- Computes severity and event volume for prioritization.
- Supports workflow states: open, acknowledged, closed.
- Supports bulk status updates and offense drill-down into contributing events.

4. Event Viewer
- Provides high-volume event browsing with time range, severity, agent, and text filters.
- Supports pagination and live refresh mode for active incident response.

5. Search and DSL
- Supports guided search via form-based filters.
- Supports direct OpenSearch DSL for advanced analysts.
- Stores recent search history locally for repeat investigations.

## Data Model and Processing

This project treats Wazuh and OpenSearch as the source of truth.

- Wazuh REST API supplies manager and agent operational state.
- OpenSearch supplies alert event data from wazuh-alerts-*.
- Offenses are computed in the frontend model layer.
- Offense status is stored locally for workflow continuity without backend mutation.

## Runtime Behavior

1. First run opens a setup wizard.
2. Wizard validates Wazuh and OpenSearch connectivity before completion.
3. Connection details are stored in browser local storage.
4. Authentication token is stored in session storage.
5. After setup, pages poll for live updates at workflow-specific intervals.

## Deployment Philosophy

This repository is built to be safe for real Wazuh environments.

- Primary deployment mode: run on the Wazuh server behind nginx.
- Recommended runtime paths in wizard: /api and /opensearch.
- Deployment is isolated on its own nginx site and port.
- Default Wazuh components are not replaced.

## Documentation Map

Use this file for product scope, analyst workflows, and frontend development.

For deployment and backend operations, use the backend guide as the single source of truth:

- backend/README.md
- backend/setup-production.sh
- backend/nginx.conf.snippet
- backend/wazuh-soc-backend.service

## Ubuntu Operations Scripts

The repo includes scripts for operational lifecycle management on Ubuntu.

1. Initial install
- scripts/install-ubuntu-wazuh-dashboard.sh
- Installs deps (optional), builds, deploys static files, configures isolated nginx site.

2. Safe update
- scripts/update-ubuntu-wazuh-dashboard.sh
- Rebuilds and redeploys static assets, validates and reloads nginx.

3. Read-only health check
- scripts/check-ubuntu-wazuh-dashboard.sh
- Verifies site wiring and endpoint reachability.

4. One-command release wrapper
- scripts/release-ubuntu-wazuh-dashboard.sh
- Auto-selects install vs update, then runs health checks.

## One-Line Server Bootstrap (curl/wget)

If you are already on the Wazuh Ubuntu server, you can pull the installer script directly and run it.

Set this first to the raw script URL in your repository:

	export INSTALLER_URL="https://raw.githubusercontent.com/mrtrick37/Wazuh-SOC/main/scripts/install-ubuntu-wazuh-dashboard.sh"

Curl (auto-clones source to $HOME/wazuh-testing if needed):

	curl -fsSL "$INSTALLER_URL" -o /tmp/install-ubuntu-wazuh-dashboard.sh && bash /tmp/install-ubuntu-wazuh-dashboard.sh

Wget (auto-clones source to $HOME/wazuh-testing if needed):

	wget -qO /tmp/install-ubuntu-wazuh-dashboard.sh "$INSTALLER_URL" && bash /tmp/install-ubuntu-wazuh-dashboard.sh

Override clone target/repo ref explicitly:

	curl -fsSL "$INSTALLER_URL" -o /tmp/install-ubuntu-wazuh-dashboard.sh && bash /tmp/install-ubuntu-wazuh-dashboard.sh --clone-dir "$HOME/wazuh-soc" --repo-ref main

Recommended for repeatable deployments (pin a commit):

	export INSTALLER_URL="https://raw.githubusercontent.com/mrtrick37/Wazuh-SOC/<commit-sha>/scripts/install-ubuntu-wazuh-dashboard.sh"
	curl -fsSL "$INSTALLER_URL" -o /tmp/install-ubuntu-wazuh-dashboard.sh && bash /tmp/install-ubuntu-wazuh-dashboard.sh --repo-ref <commit-sha> --non-interactive

## Tech Profile

- React + TypeScript + Vite
- Tailwind CSS
- TanStack Query and TanStack Table
- Recharts
- React Router

## Local Development

Prerequisites:
- Node.js 18 or later

Run:

```bash
npm install
cp .env.local.example .env.local
npm run dev
```

## Current Scope Summary

This project is not a replacement for Wazuh.

It is an analyst experience layer that:
- normalizes Wazuh + OpenSearch signals into SOC workflows,
- provides QRadar-like offense management patterns,
- and ships with a conservative deployment model suitable for production-adjacent testing.
