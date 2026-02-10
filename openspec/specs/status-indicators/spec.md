## ADDED Requirements

### Requirement: Reusable status icon function
The system SHALL provide a `get_status_icon(status)` function in lib.sh that returns an emoji icon based on PM2 status: `🟢` for "online", `🟡` for "stopped", `🔴` for "errored" or "error", `⚪` for any other status.

#### Scenario: Online environment
- **WHEN** `get_status_icon "online"` is called
- **THEN** the function outputs `🟢`

#### Scenario: Stopped environment
- **WHEN** `get_status_icon "stopped"` is called
- **THEN** the function outputs `🟡`

#### Scenario: Errored environment
- **WHEN** `get_status_icon "errored"` is called
- **THEN** the function outputs `🔴`

#### Scenario: Unknown status
- **WHEN** `get_status_icon "unknown-state"` is called
- **THEN** the function outputs `⚪`

### Requirement: Status icons in environment selection lists
The `select_environment()` function SHALL display a status icon next to each environment name by calling `get_pm2_status()` and `get_status_icon()` for each entry. The format SHALL be `  N) 🟢 environment-name`.

#### Scenario: Mixed status environments in selection
- **WHEN** `select_environment` is called and there are environments with statuses online, stopped, and errored
- **THEN** each environment line shows the corresponding icon: `1) 🟢 app-one`, `2) 🟡 app-two`, `3) 🔴 app-three`

### Requirement: Dashboard uses get_status_icon
The `show_dashboard()` function SHALL use `get_status_icon()` instead of its inline case statement for status icons, ensuring consistency with all other listing contexts.

#### Scenario: Dashboard displays status icons
- **WHEN** `show_dashboard()` renders the environment list
- **THEN** the same icons produced by `get_status_icon()` are displayed, matching the icons in `select_environment()` and all other lists
