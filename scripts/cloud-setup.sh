#!/usr/bin/env bash
# Claude Code cloud session setup (run by the SessionStart hook in .claude/settings.json).
# Installs the locked dev dependencies and the Chromium build the Playwright tests use.
set -euo pipefail

cd "$(dirname "$0")/.."
npm ci --no-audit --no-fund --loglevel=error >/dev/null
# The Playwright CDN may be outside the cloud network allowlist; the site check does not need it.
npx --no-install playwright install --with-deps chromium >/dev/null \
  || echo "cloud-setup: Playwright Chromium install failed; e2e tests unavailable" >&2
