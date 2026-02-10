## 1. Bug Fix — toggle_web_inspector()

- [x] 1.1 Implement `toggle_web_inspector()` in lib.sh after `init_web_inspector()` (~line 1865): check for `public/buildflowz-inspector.js` presence, remove JS file + sed-remove lines containing "buildflowz-inspector" from index.html, `src/layouts/*.astro`, `app/layout.tsx`, `src/app/layout.tsx` if disabling; call `init_web_inspector` if enabling
- [x] 1.2 Verify the menu call at menu_simple_color.sh:348 (`toggle_web_inspector "$PROJECT_DIR"`) works with the new function — test enable and disable paths

## 2. Foundation — Status Indicators

- [x] 2.1 Add `get_status_icon()` function to lib.sh that maps PM2 status strings to emoji icons (online→🟢, stopped→🟡, errored/error→🔴, default→⚪)
- [x] 2.2 Refactor `show_dashboard()` in lib.sh to replace its inline status icon case statement (lines 1957-1972) with calls to `get_status_icon()`

## 3. Foundation — UI Wrapper Functions

- [x] 3.1 Add gum detection to lib.sh: `HAS_GUM` flag set via `gum --version 2>/dev/null` (not auto-install)
- [x] 3.2 Implement `ui_choose()` in lib.sh — gum: pipe options to `gum choose`; fallback: numbered list with `read`
- [x] 3.3 Implement `ui_input()` in lib.sh — gum: `gum input --placeholder`; fallback: echo prompt + `read`
- [x] 3.4 Implement `ui_confirm()` in lib.sh — gum: `gum confirm`; fallback: echo prompt "(y/N)" + `read`, return 0 for yes
- [x] 3.5 Implement `ui_header()` in lib.sh — gum: `gum style` with border; fallback: echo with ANSI color codes
- [x] 3.6 Implement `ui_spinner()` in lib.sh — gum: `gum spin --spinner dot --title`; fallback: echo "Working..." + run command

## 4. Foundation — select_environment() + Credential Cache

- [x] 4.1 Move `select_environment()` from menu_simple_color.sh into lib.sh, refactor to use `ui_choose()` and add status icons via `get_pm2_status()` + `get_status_icon()` for each environment entry
- [x] 4.2 Add `BUILDFLOWZ_SECRETS_DIR` setting to config.sh (default: `$HOME/.buildflowz`)
- [x] 4.3 Implement `save_secret()` in lib.sh — create dir (chmod 700) and file (chmod 600) if needed, sed-update existing key or append new key=value
- [x] 4.4 Implement `load_secret()` in lib.sh — grep key from secrets file, output value to stdout, return 1 if not found

## 5. Feature — Batch Operations

- [x] 5.1 Implement `batch_stop_all()` in lib.sh — list envs, show count, require confirmation via `ui_confirm`, iterate with `env_stop()` showing `[N/total] Stopping <name>...`, display summary
- [x] 5.2 Implement `batch_start_all()` in lib.sh — same pattern with `env_start()`, handle individual failures (log + continue)
- [x] 5.3 Implement `batch_restart_all()` in lib.sh — same pattern with `env_restart()`

## 6. Merge — Unified menu.sh

- [x] 6.1 Rewrite `menu.sh` based on `menu_simple_color.sh` structure: source lib.sh, use `HAS_GUM` flag, replace all inline UI calls with `ui_*` wrappers
- [x] 6.2 Port `print_header()` and `show_menu()` to use `ui_header()` — keep ANSI fallback layout matching current design
- [x] 6.3 Port main menu loop: dashboard (1), start/deploy (2), restart (3), stop (4), remove (5), publish to web (6), batch operations (7 — new), more options (8), help (9), exit (0)
- [x] 6.4 Port `show_advanced_menu()`: logs, navigate projects, open code dir, toggle web inspector (using new `toggle_web_inspector()`), session identity
- [x] 6.5 Port "Publish to Web" flow (option 6) — integrate credential cache: try `load_secret DUCKDNS_SUBDOMAIN` + `load_secret DUCKDNS_TOKEN`, show cached subdomain + "Use cached? (Y/n)", prompt if missing/declined, `save_secret` after successful use
- [x] 6.6 Add batch operations submenu (option 7): display Stop All / Start All / Restart All / Back, call corresponding `batch_*` functions
- [x] 6.7 Port `show_help()` function to unified menu

## 7. Cleanup — Deprecation & Documentation

- [x] 7.1 Replace `menu_simple_color.sh` content with deprecation stub: print warning message + `exec "$SCRIPT_DIR/menu.sh"`
- [x] 7.2 Update CLAUDE.md references: change `./menu_simple_color.sh` to `./menu.sh` in Quick Reference Commands and file structure sections
- [x] 7.3 Run `bash -n menu.sh` and `bash -n lib.sh` syntax validation to verify no parse errors

## 8. Testing

- [x] 8.1 Run existing test suites to verify no regressions: `./test_validation.sh`, `./test_priority2.sh`, `./test_priority3.sh`
- [ ] 8.2 Manual smoke test: run `./menu.sh` without gum — verify all 10 menu options work (dashboard, start, restart, stop, remove, publish, batch ops, advanced, help, exit)
- [ ] 8.3 Manual smoke test: run `./menu.sh` with gum — verify gum-styled UI renders for selection, input, confirm, and header
- [ ] 8.4 Test batch operations: verify Stop All, Start All, Restart All with at least 2 environments — check progress output and cache invalidation
- [ ] 8.5 Test credential cache: run Publish to Web, enter credentials, verify `~/.buildflowz/secrets` exists with chmod 600, re-run and verify cached values are offered
- [ ] 8.6 Test toggle web inspector: enable on a project (verify JS file + script tag injected), toggle again (verify JS file + script tags removed)
