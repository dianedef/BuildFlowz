## ADDED Requirements

### Requirement: Gum auto-detection
The unified menu SHALL detect gum availability at startup using `gum --version`. A `HAS_GUM` flag SHALL be set to `true` or `false` based on the result. The menu SHALL NOT auto-install gum.

#### Scenario: Gum is installed and working
- **WHEN** `gum --version` succeeds
- **THEN** `HAS_GUM` is set to `true` and all UI wrappers use gum

#### Scenario: Gum is not installed
- **WHEN** `gum --version` fails
- **THEN** `HAS_GUM` is set to `false` and all UI wrappers use text-based fallbacks

#### Scenario: Gum is in PATH but broken
- **WHEN** `gum` is found in PATH but `gum --version` returns non-zero
- **THEN** `HAS_GUM` is set to `false` and text-based fallback is used

### Requirement: UI wrapper functions
The system SHALL provide the following UI abstraction functions in lib.sh that use gum when available and fall back to ANSI text-based equivalents:
- `ui_choose(prompt, options...)` — interactive selection
- `ui_input(prompt, [placeholder])` — text input
- `ui_confirm(prompt)` — yes/no confirmation
- `ui_header(title)` — styled header display
- `ui_spinner(title, command)` — loading indicator while command runs

#### Scenario: ui_choose with gum
- **WHEN** `HAS_GUM` is `true` and `ui_choose` is called with a prompt and options
- **THEN** options are presented via `gum choose` and the selected value is output to stdout

#### Scenario: ui_choose without gum
- **WHEN** `HAS_GUM` is `false` and `ui_choose` is called
- **THEN** options are displayed as a numbered list, user enters a number, and the selected value is output to stdout

#### Scenario: ui_confirm with gum
- **WHEN** `HAS_GUM` is `true` and `ui_confirm "Are you sure?"` is called
- **THEN** `gum confirm "Are you sure?"` is executed and its exit code is returned

#### Scenario: ui_confirm without gum
- **WHEN** `HAS_GUM` is `false` and `ui_confirm` is called
- **THEN** the prompt is displayed with "(y/N)" and the user's input is evaluated (returns 0 for yes, 1 otherwise)

### Requirement: Unified menu file
The system SHALL have a single `menu.sh` file that replaces both `menu.sh` and `menu_simple_color.sh`. The unified menu SHALL include all Phase 1 features: dashboard, start/deploy (smart start), restart, stop, remove, publish to web, advanced options (logs, navigate, open code, toggle web inspector, session identity), and help.

#### Scenario: Running menu.sh without gum
- **WHEN** user runs `./menu.sh` and gum is not installed
- **THEN** the full menu is displayed using ANSI color text with numbered options, matching all current `menu_simple_color.sh` functionality

#### Scenario: Running menu.sh with gum
- **WHEN** user runs `./menu.sh` and gum is installed
- **THEN** the full menu is displayed using gum-styled UI elements with the same feature set

### Requirement: Deprecation stub for menu_simple_color.sh
After merging, `menu_simple_color.sh` SHALL be replaced with a stub that prints a deprecation warning and then sources/exec's `menu.sh`.

#### Scenario: User runs deprecated menu_simple_color.sh
- **WHEN** user runs `./menu_simple_color.sh`
- **THEN** a warning "DEPRECATED: menu_simple_color.sh has been merged into menu.sh. Please use ./menu.sh instead." is displayed, and then `menu.sh` is executed

### Requirement: select_environment moved to lib.sh
The `select_environment()` function SHALL be moved from the menu file into `lib.sh` so it is available to all scripts. It SHALL use `ui_choose` internally for gum/text abstraction.

#### Scenario: select_environment called from lib.sh consumer
- **WHEN** any script that sources lib.sh calls `select_environment "Pick an env"`
- **THEN** the function lists environments with status icons and returns the selected environment name via stdout
