## ADDED Requirements

### Requirement: Batch stop all environments
The system SHALL provide a `batch_stop_all()` function that stops every PM2-managed environment in sequence. The function SHALL list all environments via `list_all_environments()`, display the count, require user confirmation before proceeding, show per-environment progress, and invalidate the PM2 cache after completion.

#### Scenario: User confirms batch stop
- **WHEN** user selects "Batch Operations > Stop All" and confirms with "yes"
- **THEN** the system stops each environment using `env_stop()`, displays progress as `[N/total] Stopping <name>...`, and shows a summary count of successfully stopped environments

#### Scenario: User cancels batch stop
- **WHEN** user selects "Stop All" and does not confirm
- **THEN** no environments are stopped and the system returns to the menu

#### Scenario: No environments exist
- **WHEN** user selects "Stop All" but `list_all_environments()` returns empty
- **THEN** the system displays a "no environments found" message and returns to the menu

### Requirement: Batch start all environments
The system SHALL provide a `batch_start_all()` function that starts every PM2-managed environment in sequence. The function SHALL use `env_start()` per environment with the same confirmation, progress, and cache invalidation pattern as batch stop.

#### Scenario: User confirms batch start
- **WHEN** user selects "Start All" and confirms
- **THEN** the system starts each environment using `env_start()`, displays per-environment progress, and shows a summary count

#### Scenario: Individual environment fails to start
- **WHEN** an individual `env_start()` call fails during batch start
- **THEN** the system logs the error, displays a failure indicator for that environment, continues with the remaining environments, and includes the failure in the summary

### Requirement: Batch restart all environments
The system SHALL provide a `batch_restart_all()` function that restarts every PM2-managed environment in sequence using `env_restart()` per environment, following the same confirmation and progress pattern.

#### Scenario: User confirms batch restart
- **WHEN** user selects "Restart All" and confirms
- **THEN** the system restarts each environment using `env_restart()`, displays per-environment progress, and shows a summary count

### Requirement: Batch operations menu integration
The system SHALL expose batch operations as a top-level menu item (option 7) with a submenu offering "Stop All", "Start All", "Restart All", and "Back".

#### Scenario: User navigates to batch operations
- **WHEN** user selects option 7 from the main menu
- **THEN** the system displays a submenu with Stop All, Start All, Restart All, and Back options
