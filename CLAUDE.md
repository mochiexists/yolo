# CLAUDE.md

Read README.md first. The landing page (`index.html`) and `install.sh` are served from mochiexists.com/yolo/, so anything merged to `main` reaches users on their next `curl | sh`.

## Cloud sessions

For Claude Code on the web (claude.ai/code). `scripts/cloud-setup.sh` runs automatically at session start (`npm ci` plus Playwright Chromium).

- Check: `python3 scripts/check-site.py && npm run test:unit` (site titles/descriptions/links, then the replay unit test; offline).
- Browser smoke tests: `npm run test:e2e` (Playwright; needs the Chromium that setup tries to install).
- Installer end-to-end test: `sh test.sh` (uses throwaway HOME directories).
- Work on the session's branch and open a PR. Merging to `main` publishes via the GitHub Pages workflow (`.github/workflows/pages.yml`), so never push `main`. There are no deploy scripts; do not push the `apps-script/` leaderboard with clasp.
- No secrets are available or needed. Keep changes small and in the site's voice.
