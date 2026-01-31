#!/bin/bash
# ============================================================================
# BuildFlowz Shared Library
# ============================================================================
#
# Description:
#   Core library containing all reusable functions for BuildFlowz CLI.
#   Handles environment management, PM2 operations, port allocation,
#   Flox integration, validation, logging, and caching.
#
# Dependencies:
#   - pm2 (required)
#   - node (required)
#   - flox (optional)
#   - git (optional)
#   - jq (optional, preferred for JSON parsing)
#   - python3 (optional, fallback for JSON parsing)
#
# Author: BuildFlowz Team
# Version: 2.0.0
# Date: 2026-01-24
# ============================================================================

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration
source "$SCRIPT_DIR/config.sh"

# ============================================================================
# ERROR HANDLING SETUP
# ============================================================================

# Enable strict mode if configured
if [ "$BUILDFLOWZ_STRICT_MODE" = "true" ]; then
    set -euo pipefail
fi

# Error trap handler
error_trap_handler() {
    local exit_code=$?
    local line_number=$1
    log ERROR "Script failed at line $line_number with exit code $exit_code"
    error "Script execution failed (line $line_number, code $exit_code)"
}

# Install error trap if configured
if [ "$BUILDFLOWZ_ERROR_TRAPS" = "true" ]; then
    trap 'error_trap_handler ${LINENO}' ERR
fi

# Cleanup trap for temporary files
TEMP_FILES=()
cleanup_temp_files() {
    for file in "${TEMP_FILES[@]}"; do
        [ -f "$file" ] && rm -f "$file" 2>/dev/null || true
    done
}
trap cleanup_temp_files EXIT

# Register a temp file for cleanup
register_temp_file() {
    TEMP_FILES+=("$1")
}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Config (use centralized config values)
PROJECTS_DIR="${BUILDFLOWZ_PROJECTS_DIR}"

# ============================================================================
# STRUCTURED LOGGING
# ============================================================================

# Ensure log directory exists
init_logging() {
    if [ "$BUILDFLOWZ_LOGGING_ENABLED" = "true" ]; then
        mkdir -p "$BUILDFLOWZ_LOG_DIR" 2>/dev/null || true

        # Rotate old logs
        if [ -f "$BUILDFLOWZ_LOG_FILE" ]; then
            local log_size=$(stat -f%z "$BUILDFLOWZ_LOG_FILE" 2>/dev/null || stat -c%s "$BUILDFLOWZ_LOG_FILE" 2>/dev/null || echo 0)
            # Rotate if larger than 10MB
            if [ "$log_size" -gt 10485760 ]; then
                mv "$BUILDFLOWZ_LOG_FILE" "$BUILDFLOWZ_LOG_FILE.$(date +%s)" 2>/dev/null || true

                # Clean old logs
                find "$BUILDFLOWZ_LOG_DIR" -name "*.log.*" -mtime +$BUILDFLOWZ_LOG_RETENTION_DAYS -delete 2>/dev/null || true
            fi
        fi
    fi
}

# Structured logging function
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Check if logging is enabled
    if [ "$BUILDFLOWZ_LOGGING_ENABLED" != "true" ]; then
        return 0
    fi

    # Check log level filtering
    local level_priority=0
    case "$level" in
        DEBUG) level_priority=0 ;;
        INFO) level_priority=1 ;;
        WARNING) level_priority=2 ;;
        ERROR) level_priority=3 ;;
    esac

    local config_priority=1  # Default to INFO
    case "$BUILDFLOWZ_LOG_LEVEL" in
        DEBUG) config_priority=0 ;;
        INFO) config_priority=1 ;;
        WARNING) config_priority=2 ;;
        ERROR) config_priority=3 ;;
    esac

    # Only log if level meets threshold
    if [ $level_priority -lt $config_priority ]; then
        return 0
    fi

    # Format: [TIMESTAMP] [LEVEL] message
    local log_entry="[$timestamp] [$level] $message"

    # Append to log file
    echo "$log_entry" >> "$BUILDFLOWZ_LOG_FILE" 2>/dev/null || true
}

# Initialize logging on load
init_logging

# ============================================================================
# JSON PARSING UTILITIES (Priority 3 #9: jq over Python)
# ============================================================================

# -----------------------------------------------------------------------------
# parse_json - Parse JSON data with jq or python fallback
#
# Description:
#   Parses JSON using jq if available (faster), falls back to python3.
#   Automatically chooses best available tool.
#
# Arguments:
#   $1 - JQ expression (e.g., '.[] | .name')
#   stdin - JSON data to parse
#
# Returns:
#   Parsed output
#
# Example:
#   echo '{"name":"test"}' | parse_json '.name'
# -----------------------------------------------------------------------------
parse_json() {
    local jq_expr=$1

    # Prefer jq if available and configured
    if [ "$BUILDFLOWZ_PREFER_JQ" = "true" ] && command -v jq >/dev/null 2>&1; then
        jq -r "$jq_expr" 2>/dev/null || {
            log ERROR "jq parsing failed with expression: $jq_expr"
            return 1
        }
    elif command -v python3 >/dev/null 2>&1; then
        # Fallback to python3
        # Convert jq expression to python (basic support)
        python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    # Note: This is a simplified fallback, not full jq compatibility
    print(data)
except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null || {
            log ERROR "python3 JSON parsing failed"
            return 1
        }
    else
        log ERROR "No JSON parser available (install jq or python3)"
        error "No JSON parser available"
        return 1
    fi
}

# ============================================================================
# PREREQUISITE & VALIDATION FUNCTIONS
# ============================================================================

# -----------------------------------------------------------------------------
# check_prerequisites - Validate required and optional tools are installed
#
# Description:
#   Checks for critical tools (pm2, node) and warns about missing optional
#   tools (flox, git, jq, python3). Fails if critical tools are missing.
#
# Arguments:
#   None
#
# Returns:
#   0 - All required tools present
#   1 - Missing required tools
#
# Outputs:
#   Error messages for missing required tools
#   Warning messages for missing optional tools
#
# Example:
#   check_prerequisites || exit 1
# -----------------------------------------------------------------------------
check_prerequisites() {
    local missing=()
    local warnings=()

    # Critical tools
    for cmd in pm2 node; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done

    # Optional but recommended tools
    for cmd in flox git python3; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            warnings+=("$cmd")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        error "Missing required tools: ${missing[*]}"
        info "Run: ./install.sh or install manually"
        return 1
    fi

    if [ ${#warnings[@]} -gt 0 ]; then
        warning "Optional tools missing: ${warnings[*]}"
        info "Some features may not work properly"
    fi

    return 0
}

# -----------------------------------------------------------------------------
# validate_project_path - Validate project directory path for security
#
# Description:
#   Validates a project path to prevent security vulnerabilities:
#   - Path traversal attacks (.. sequences)
#   - Command injection (special characters)
#   - Access to unsafe directories
#   - Non-existent paths
#
# Arguments:
#   $1 - Path to validate
#
# Returns:
#   0 - Path is valid and safe
#   1 - Path is invalid or unsafe
#
# Security:
#   Blocks: .., ;, &, |, $, backticks
#   Allows only: /root/*, /home/*, /opt/*
#
# Example:
#   validate_project_path "/root/myapp" || exit 1
# -----------------------------------------------------------------------------
validate_project_path() {
    local path=$1

    # Must not be empty
    if [ -z "$path" ]; then
        error "Path cannot be empty"
        return 1
    fi

    # Must be absolute path
    if [[ "$path" != /* ]]; then
        error "Path must be absolute (start with /)"
        return 1
    fi

    # Must start with /root or be a known safe directory
    if [[ "$path" != "/root" ]] && [[ "$path" != /root/* ]] && \
       [[ "$path" != "/home" ]] && [[ "$path" != /home/* ]] && \
       [[ "$path" != "/opt" ]] && [[ "$path" != /opt/* ]]; then
        error "Path must be under /root, /home, or /opt for safety"
        return 1
    fi

    # Must not contain path traversal attempts
    if [[ "$path" == *..* ]]; then
        error "Path cannot contain '..' (path traversal blocked)"
        return 1
    fi

    # Must not contain suspicious characters
    if [[ "$path" =~ [\;\&\|\$\`] ]]; then
        error "Path contains invalid characters"
        return 1
    fi

    # Must exist and be a directory
    if [ ! -d "$path" ]; then
        error "Path does not exist or is not a directory: $path"
        return 1
    fi

    return 0
}

# -----------------------------------------------------------------------------
# validate_env_name - Validate environment/project name
#
# Description:
#   Ensures environment names follow safe naming conventions.
#
# Arguments:
#   $1 - Environment name to validate
#
# Returns:
#   0 - Name is valid
#   1 - Name is invalid
#
# Rules:
#   - Only alphanumeric, dash, underscore, dot allowed
#   - Cannot start with dash or dot
#   - Cannot be empty
#
# Example:
#   validate_env_name "my-app" || exit 1
# -----------------------------------------------------------------------------
validate_env_name() {
    local name=$1

    if [ -z "$name" ]; then
        error "Environment name cannot be empty"
        return 1
    fi

    # Must contain only alphanumeric, dash, underscore, dot
    if [[ ! "$name" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        error "Environment name can only contain letters, numbers, dash, underscore, dot"
        return 1
    fi

    # Must not start with dash or dot
    if [[ "$name" =~ ^[-.] ]]; then
        error "Environment name cannot start with dash or dot"
        return 1
    fi

    return 0
}

# Helper functions (with logging)
success() {
    echo -e "${GREEN}✅${NC} $1"
    log INFO "SUCCESS: $1"
}

error() {
    echo -e "${RED}❌${NC} $1"
    log ERROR "$1"
}

info() {
    echo -e "${BLUE}ℹ️${NC} $1"
    log INFO "$1"
}

warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
    log WARNING "$1"
}

# ============================================================================
# PM2 DATA CACHING (Performance Optimization)
# ============================================================================

# Global cache variables
PM2_DATA_CACHE=""
PM2_DATA_CACHE_TIME=0

# -----------------------------------------------------------------------------
# get_pm2_data_cached - Fetch and cache all PM2 application data
#
# Description:
#   Retrieves all PM2 app data in a single call and caches the results.
#   Uses jq for JSON parsing (falls back to python3).
#   Cache is valid for BUILDFLOWZ_PM2_CACHE_TTL seconds (default: 5).
#
# Arguments:
#   None
#
# Returns:
#   0 - Success
#   1 - PM2 not installed or error
#
# Outputs:
#   name|status|port|cwd for each PM2 app (one per line)
#
# Cache Behavior:
#   - Returns cached data if age < TTL
#   - Fetches fresh data if cache expired
#   - Global variables: PM2_DATA_CACHE, PM2_DATA_CACHE_TIME
#
# Example:
#   get_pm2_data_cached
# -----------------------------------------------------------------------------
get_pm2_data_cached() {
    local current_time=$(date +%s)
    local cache_age=$((current_time - PM2_DATA_CACHE_TIME))

    # Return cached data if fresh
    if [ "$BUILDFLOWZ_PM2_CACHE_ENABLED" = "true" ] && [ $cache_age -lt $BUILDFLOWZ_PM2_CACHE_TTL ] && [ -n "$PM2_DATA_CACHE" ]; then
        log DEBUG "Using cached PM2 data (age: ${cache_age}s)"
        echo "$PM2_DATA_CACHE"
        return 0
    fi

    # Fetch fresh data
    log DEBUG "Fetching fresh PM2 data"
    if ! command -v pm2 >/dev/null 2>&1; then
        log WARNING "PM2 not installed"
        return 1
    fi

    # Get all PM2 data in one call: name|status|port|cwd
    # Use jq if available (faster), fallback to python3
    if [ "$BUILDFLOWZ_PREFER_JQ" = "true" ] && command -v jq >/dev/null 2>&1; then
        PM2_DATA_CACHE=$(pm2 jlist 2>/dev/null | jq -r '.[] | "\(.name)|\(.pm2_env.status // "unknown")|\(.pm2_env.env.PORT // "")|\(.pm2_env.pm_cwd // "")"' 2>/dev/null)
    elif command -v python3 >/dev/null 2>&1; then
        PM2_DATA_CACHE=$(pm2 jlist 2>/dev/null | python3 -c "
import sys, json
try:
    apps = json.load(sys.stdin)
    for app in apps:
        name = app.get('name', '')
        status = app.get('pm2_env', {}).get('status', 'unknown')
        port = app.get('pm2_env', {}).get('env', {}).get('PORT', '')
        cwd = app.get('pm2_env', {}).get('pm_cwd', '')
        print(f'{name}|{status}|{port}|{cwd}')
except Exception as e:
    import sys
    print(f'ERROR: {e}', file=sys.stderr)
" 2>/dev/null)
    else
        log ERROR "No JSON parser available (jq or python3 required)"
        return 1
    fi

    PM2_DATA_CACHE_TIME=$current_time
    echo "$PM2_DATA_CACHE"
}

# -----------------------------------------------------------------------------
# invalidate_pm2_cache - Clear PM2 data cache
#
# Description:
#   Invalidates the PM2 data cache to force a fresh fetch on next access.
#   Should be called after any PM2 state changes (start, stop, delete).
#
# Arguments:
#   None
#
# Returns:
#   0 - Always succeeds
#
# Example:
#   pm2 start app.js
#   invalidate_pm2_cache
# -----------------------------------------------------------------------------
invalidate_pm2_cache() {
    log DEBUG "Invalidating PM2 cache"
    PM2_DATA_CACHE=""
    PM2_DATA_CACHE_TIME=0
}

# -----------------------------------------------------------------------------
# get_pm2_app_data - Extract specific PM2 app data from cache
#
# Description:
#   Retrieves a specific field for a PM2 app from the cached data.
#
# Arguments:
#   $1 - App name
#   $2 - Field to retrieve: "status", "port", "cwd", or empty for all
#
# Returns:
#   0 - App found
#   1 - App not found or cache empty
#
# Outputs:
#   Requested field value(s)
#
# Example:
#   port=$(get_pm2_app_data "myapp" "port")
# -----------------------------------------------------------------------------
get_pm2_app_data() {
    local app_name=$1
    local field=$2  # status, port, or cwd

    local data=$(get_pm2_data_cached)
    if [ -z "$data" ]; then
        return 1
    fi

    # Parse cached data
    echo "$data" | while IFS='|' read -r name status port cwd; do
        if [ "$name" = "$app_name" ]; then
            case "$field" in
                status) echo "$status" ;;
                port) echo "$port" ;;
                cwd) echo "$cwd" ;;
                *) echo "$status|$port|$cwd" ;;
            esac
            return 0
        fi
    done
}

# ============================================================================
# PORT MANAGEMENT FUNCTIONS
# ============================================================================

# -----------------------------------------------------------------------------
# is_port_in_use - Check if a TCP port is currently in use
#
# Description:
#   Uses ss command to check if a port is listening.
#
# Arguments:
#   $1 - Port number to check
#
# Returns:
#   0 - Port is in use
#   1 - Port is available
#
# Example:
#   if is_port_in_use 3000; then
#       echo "Port 3000 is busy"
#   fi
# -----------------------------------------------------------------------------
is_port_in_use() {
    local port=$1
    ss -ltn 2>/dev/null | awk '{print $4}' | grep -E "[:.]${port}$" >/dev/null 2>&1
}

# Get all ports used by PM2 apps (even stopped ones) - OPTIMIZED
get_all_pm2_ports() {
    if ! command -v pm2 >/dev/null 2>&1; then
        return 0
    fi

    local data=$(get_pm2_data_cached)
    if [ -z "$data" ]; then
        return 0
    fi

    # Extract ports from cached data
    echo "$data" | awk -F'|' '{if ($3 != "") print $3}' | tr '\n' ' '
}

# -----------------------------------------------------------------------------
# find_available_port - Find next available port in range
#
# Description:
#   Searches for an available port starting from base_port.
#   Checks both active ports (via ss) and PM2-assigned ports.
#
# Arguments:
#   $1 - Base port to start search (default: BUILDFLOWZ_PORT_RANGE_START)
#
# Returns:
#   0 - Available port found
#   1 - No available port in range
#
# Outputs:
#   Available port number to stdout
#
# Notes:
#   - Searches up to BUILDFLOWZ_PORT_MAX_ATTEMPTS ports
#   - Avoids race conditions by checking both active and reserved ports
#
# Example:
#   port=$(find_available_port 3000)
# -----------------------------------------------------------------------------
find_available_port() {
    local base_port=${1:-$BUILDFLOWZ_PORT_RANGE_START}
    local max_range=$BUILDFLOWZ_PORT_MAX_ATTEMPTS
    local port=$base_port

    # Get all ports already assigned in PM2 (atomic read)
    local pm2_ports=$(get_all_pm2_ports)

    # Search for available port
    while [ $((port - base_port)) -lt $max_range ]; do
        # Double-check: not in use AND not already assigned in PM2
        # This reduces race condition window
        if ! is_port_in_use $port && ! echo "$pm2_ports" | grep -q "\<$port\>"; then
            # Final verification before returning
            if ! is_port_in_use $port; then
                echo $port
                log DEBUG "Found available port: $port"
                return 0
            fi
        fi
        port=$((port + 1))
    done

    error "Impossible de trouver un port disponible après $max_range tentatives"
    log ERROR "Port exhaustion: no ports available in range $base_port-$((base_port + max_range))"
    return 1
}

# Get project status from PM2 - OPTIMIZED
get_pm2_status() {
    local identifier=$1
    local project_dir=$(resolve_project_path "$identifier")

    if [ -z "$project_dir" ]; then
        echo "not-found"
        return 1
    fi

    local env_name=$(basename "$project_dir") # Use basename as the PM2 app name

    if ! command -v pm2 >/dev/null 2>&1; then
        echo "pm2-not-installed"
        return 1
    fi

    # Use cached data
    local status=$(get_pm2_app_data "$env_name" "status")

    if [ -n "$status" ]; then
        echo "$status"
        return 0
    else
        echo "not_found"
        return 0
    fi
}

# Get project directory path


# Get port from PM2 env vars for a project - OPTIMIZED
get_port_from_pm2() {
    local identifier=$1
    local project_dir=$(resolve_project_path "$identifier")

    if [ -z "$project_dir" ]; then
        return 1
    fi

    local env_name=$(basename "$project_dir") # Use basename as the PM2 app name

    if ! command -v pm2 >/dev/null 2>&1; then
        return 1
    fi

    # Use cached data
    local port=$(get_pm2_app_data "$env_name" "port")

    if [ -n "$port" ]; then
        echo "$port"
        return 0
    fi

    return 1
}


# -----------------------------------------------------------------------------
# resolve_project_path - Resolve project directory from identifier
#
# Description:
#   Converts an environment name or path to an absolute project directory.
#   Searches for .flox directory to confirm valid project.
#
# Arguments:
#   $1 - Environment name or absolute path
#
# Returns:
#   0 - Project found
#   1 - Project not found
#
# Outputs:
#   Absolute path to project directory
#
# Search Strategy:
#   1. If absolute path with .flox, return as-is
#   2. Search PROJECTS_DIR for matching name with .flox
#
# Example:
#   path=$(resolve_project_path "myapp")
#   path=$(resolve_project_path "/root/myapp")
# -----------------------------------------------------------------------------
resolve_project_path() {
    local identifier=$1

    # Case 1: Identifier is already an absolute path
    if [[ "$identifier" == /* && -d "$identifier" && -d "$identifier/.flox" ]]; then
        echo "$identifier"
        return 0
    fi

    # Case 2: Identifier is an environment name, search within PROJECTS_DIR
    local found_path
    found_path=$(find "$PROJECTS_DIR" -maxdepth 4 -type d -name "$identifier" 2>/dev/null | while read -r project_dir; do
        if [ -d "$project_dir/.flox" ]; then
            echo "$project_dir"
            exit 0
        fi
    done)

    if [ -n "$found_path" ]; then
        echo "$found_path"
        return 0
    fi
    
    return 1 # Project not found
}

# List all environments (projects with Flox env)
list_all_environments() {
    if [ -d "$PROJECTS_DIR" ]; then
        find "$PROJECTS_DIR" -maxdepth 4 -type d -name ".flox" 2>/dev/null | while read -r flox_dir; do
            # Extract the project name from the path, e.g., /root/my-robots/chatbot/.flox -> chatbot
            echo "$(basename "$(dirname "$flox_dir")")"
        done | grep -v "^\.$" | sort
    fi
}

# List all environment identifiers (for menu selection)
list_all_environment_identifiers() {
    list_all_environments
    # Add any other known project paths that might not be detected by list_all_environments but exist
    # For example, if you want to explicitly add /root/my-robots/chatbot as an option
    if [ -d "/root/my-robots/chatbot/.flox" ]; then
        echo "/root/my-robots/chatbot"
    fi
}


# Cleanup orphan projects
cleanup_orphan_projects() {
    echo -e "${YELLOW}🔍 Recherche de projets orphelins...${NC}"
    
    if [ -d "$PROJECTS_DIR" ]; then
        find "$PROJECTS_DIR" -maxdepth 1 -type d ! -path "$PROJECTS_DIR" | while read -r dir; do
            if [ ! -d "$dir/.flox" ]; then
                project_name=$(basename "$dir")
                echo -e "${YELLOW}🗑️  Projet sans Flox détecté: $project_name${NC}"
                echo -e "${YELLOW}   (pas d'environnement Flox)${NC}"
            fi
        done
    fi
    
    echo -e "${GREEN}✅ Nettoyage terminé${NC}"
}

# ============================================================================
# SESSION IDENTITY FUNCTIONS
# ============================================================================

# Word list for human-readable session codes
SESSION_WORDS=(
    "CORAL" "WAVE" "STORM" "TIGER" "EMBER" "FROST" "SOLAR" "LUNAR" "DELTA" "ALPHA"
    "CYBER" "NEXUS" "PULSE" "DRIFT" "SPARK" "BLAZE" "CLOUD" "SWIFT" "GHOST" "PRIME"
    "OMEGA" "SIGMA" "AZURE" "FLAME" "SHADE" "LIGHT" "STONE" "RIVER" "FORGE" "STEEL"
    "NOVA" "QUEST" "PIXEL" "VORTEX" "COMET" "ORBIT" "PRISM" "QUARK" "SONIC" "TURBO"
    "BOLT" "FLASH" "FROST" "GLEAM" "HAZE" "JADE" "KARMA" "LOTUS" "MAGIC" "NEON"
)

# -----------------------------------------------------------------------------
# init_session - Initialize session identity for this server/user
#
# Description:
#   Creates the session directory and generates a unique session ID if not
#   already present. The session ID is based on USER, HOSTNAME, and creation
#   timestamp, making it unique and persistent.
#
# Arguments:
#   None
#
# Returns:
#   0 - Success
#   1 - Error creating directory
#
# Side Effects:
#   - Creates ~/.buildflowz/session/ directory
#   - Creates session_id file if not present
#
# Example:
#   init_session
# -----------------------------------------------------------------------------
init_session() {
    if [ "$BUILDFLOWZ_SESSION_ENABLED" != "true" ]; then
        return 0
    fi

    # Create session directory
    if ! mkdir -p "$BUILDFLOWZ_SESSION_DIR" 2>/dev/null; then
        log ERROR "Failed to create session directory: $BUILDFLOWZ_SESSION_DIR"
        return 1
    fi

    local session_file="$BUILDFLOWZ_SESSION_DIR/session_id"

    # Generate session ID if not present
    if [ ! -f "$session_file" ]; then
        local timestamp=$(date +%s)
        local user="${USER:-unknown}"
        local host="${HOSTNAME:-$(hostname 2>/dev/null || echo 'unknown')}"
        local random_part=$(head -c 16 /dev/urandom 2>/dev/null | od -An -tx1 | tr -d ' \n' || echo "$RANDOM$RANDOM")

        # Create unique session ID
        local session_id="${user}@${host}:${timestamp}:${random_part}"

        echo "$session_id" > "$session_file"
        log INFO "Created new session ID for $user@$host"
    fi

    return 0
}

# -----------------------------------------------------------------------------
# get_session_id - Retrieve the current session ID
#
# Description:
#   Returns the session ID, initializing the session if needed.
#
# Arguments:
#   None
#
# Returns:
#   0 - Success
#   1 - Session disabled or error
#
# Outputs:
#   Session ID string to stdout
#
# Example:
#   session_id=$(get_session_id)
# -----------------------------------------------------------------------------
get_session_id() {
    if [ "$BUILDFLOWZ_SESSION_ENABLED" != "true" ]; then
        return 1
    fi

    local session_file="$BUILDFLOWZ_SESSION_DIR/session_id"

    # Initialize if needed
    if [ ! -f "$session_file" ]; then
        init_session || return 1
    fi

    cat "$session_file" 2>/dev/null
}

# -----------------------------------------------------------------------------
# generate_hash_art - Generate deterministic ASCII art from session ID
#
# Description:
#   Creates a unique 5x20 ASCII pattern from a session ID using SHA256 hash.
#   The pattern is deterministic - same session ID always produces same art.
#
# Arguments:
#   $1 - Session ID string
#
# Returns:
#   0 - Success
#
# Outputs:
#   5-line ASCII art pattern to stdout
#
# Example:
#   generate_hash_art "user@host:123456:abc"
# -----------------------------------------------------------------------------
generate_hash_art() {
    local session_id="$1"

    if [ -z "$session_id" ]; then
        return 1
    fi

    # Generate SHA256 hash
    local hash
    if command -v sha256sum >/dev/null 2>&1; then
        hash=$(echo -n "$session_id" | sha256sum | cut -d' ' -f1)
    elif command -v shasum >/dev/null 2>&1; then
        hash=$(echo -n "$session_id" | shasum -a 256 | cut -d' ' -f1)
    else
        # Fallback: use md5 if available
        if command -v md5sum >/dev/null 2>&1; then
            hash=$(echo -n "$session_id" | md5sum | cut -d' ' -f1)
            hash="${hash}${hash}"  # Double it for length
        else
            log ERROR "No hash utility available (sha256sum, shasum, or md5sum)"
            return 1
        fi
    fi

    # Characters for the art (from sparse to dense)
    local chars=("·" "░" "▒" "▓" "█")
    local width=20
    local height=5
    local art=""

    for ((row=0; row<height; row++)); do
        local line=""
        for ((col=0; col<width; col++)); do
            # Extract 2 characters from hash based on position
            local pos=$(( (row * width + col) * 2 % 64 ))
            local hex_val="${hash:$pos:2}"

            # Convert hex to decimal and map to character index (0-4)
            local dec_val=$((16#$hex_val % 5))
            line+="${chars[$dec_val]}"
        done

        if [ $row -lt $((height - 1)) ]; then
            art+="$line\n"
        else
            art+="$line"
        fi
    done

    echo -e "$art"
}

# -----------------------------------------------------------------------------
# get_session_code - Generate human-readable session code
#
# Description:
#   Creates a memorable code in format WORD-WORD-XX from session ID.
#   Deterministic - same session ID always produces same code.
#
# Arguments:
#   $1 - Session ID string
#
# Returns:
#   0 - Success
#
# Outputs:
#   Session code string (e.g., "CORAL-WAVE-7F") to stdout
#
# Example:
#   code=$(get_session_code "user@host:123456:abc")
# -----------------------------------------------------------------------------
get_session_code() {
    local session_id="$1"

    if [ -z "$session_id" ]; then
        return 1
    fi

    # Generate hash
    local hash
    if command -v sha256sum >/dev/null 2>&1; then
        hash=$(echo -n "$session_id" | sha256sum | cut -d' ' -f1)
    elif command -v shasum >/dev/null 2>&1; then
        hash=$(echo -n "$session_id" | shasum -a 256 | cut -d' ' -f1)
    elif command -v md5sum >/dev/null 2>&1; then
        hash=$(echo -n "$session_id" | md5sum | cut -d' ' -f1)
    else
        echo "UNKNOWN"
        return 1
    fi

    # Get word indices from hash
    local word_count=${#SESSION_WORDS[@]}
    local idx1=$((16#${hash:0:4} % word_count))
    local idx2=$((16#${hash:4:4} % word_count))
    local hex_suffix="${hash:8:2}"

    # Build code
    local word1="${SESSION_WORDS[$idx1]}"
    local word2="${SESSION_WORDS[$idx2]}"

    echo "${word1}-${word2}-${hex_suffix^^}"
}

# -----------------------------------------------------------------------------
# display_session_banner - Display formatted session identity banner
#
# Description:
#   Shows the hash art and session code in a formatted box.
#   Used by server-side menus to display identity.
#
# Arguments:
#   None
#
# Returns:
#   0 - Success
#   1 - Session disabled
#
# Outputs:
#   Formatted banner to stdout
#
# Example:
#   display_session_banner
# -----------------------------------------------------------------------------
display_session_banner() {
    if [ "$BUILDFLOWZ_SESSION_ENABLED" != "true" ]; then
        return 1
    fi

    local session_id=$(get_session_id)
    if [ -z "$session_id" ]; then
        return 1
    fi

    local hash_art=$(generate_hash_art "$session_id")
    local session_code=$(get_session_code "$session_id")
    local user="${USER:-unknown}"
    local host="${HOSTNAME:-$(hostname 2>/dev/null || echo 'unknown')}"

    echo -e "${CYAN}──────────────────────────────────────────────────${NC}"
    echo -e "${MAGENTA}  Session Identity${NC}"
    echo -e "${CYAN}──────────────────────────────────────────────────${NC}"
    echo ""

    # Display hash art (centered visually)
    while IFS= read -r line; do
        echo -e "              ${BLUE}$line${NC}"
    done <<< "$hash_art"

    echo ""
    echo -e "  ${GREEN}$user@$host${NC}    ${YELLOW}$session_code${NC}"
    echo -e "${CYAN}──────────────────────────────────────────────────${NC}"
}

# -----------------------------------------------------------------------------
# reset_session - Regenerate session identity
#
# Description:
#   Deletes the existing session ID and creates a new one.
#   Use this if you want a fresh identity or if the session was compromised.
#
# Arguments:
#   None
#
# Returns:
#   0 - Success
#   1 - Error
#
# Side Effects:
#   - Deletes existing session_id file
#   - Creates new session_id with fresh timestamp
#
# Example:
#   reset_session
# -----------------------------------------------------------------------------
reset_session() {
    if [ "$BUILDFLOWZ_SESSION_ENABLED" != "true" ]; then
        echo "Session identity is disabled"
        return 1
    fi

    local session_file="$BUILDFLOWZ_SESSION_DIR/session_id"

    # Remove existing session
    if [ -f "$session_file" ]; then
        rm -f "$session_file"
        log INFO "Removed existing session ID"
    fi

    # Create new session
    init_session

    local new_id=$(get_session_id)
    local new_code=$(get_session_code "$new_id")

    echo -e "${GREEN}✅ Session identity reset${NC}"
    echo -e "${YELLOW}New session code: ${CYAN}$new_code${NC}"
    log INFO "Session identity reset - new code: $new_code"

    return 0
}

# -----------------------------------------------------------------------------
# get_session_info - Get detailed session information
#
# Description:
#   Returns detailed information about the current session including
#   creation time and user/host info.
#
# Arguments:
#   None
#
# Returns:
#   0 - Success
#
# Outputs:
#   Formatted session info to stdout
#
# Example:
#   get_session_info
# -----------------------------------------------------------------------------
get_session_info() {
    if [ "$BUILDFLOWZ_SESSION_ENABLED" != "true" ]; then
        echo "Session identity is disabled"
        return 1
    fi

    local session_id=$(get_session_id)
    if [ -z "$session_id" ]; then
        echo "No session found"
        return 1
    fi

    # Parse session ID components
    local user_host=$(echo "$session_id" | cut -d: -f1)
    local timestamp=$(echo "$session_id" | cut -d: -f2)
    local session_code=$(get_session_code "$session_id")

    # Convert timestamp to readable date
    local created_date
    if date -d "@$timestamp" &>/dev/null; then
        created_date=$(date -d "@$timestamp" '+%Y-%m-%d %H:%M:%S')
    else
        created_date=$(date -r "$timestamp" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "Unknown")
    fi

    echo -e "${CYAN}Session Information:${NC}"
    echo -e "  ${BLUE}User@Host:${NC}    $user_host"
    echo -e "  ${BLUE}Session Code:${NC} ${YELLOW}$session_code${NC}"
    echo -e "  ${BLUE}Created:${NC}      $created_date"
    echo -e "  ${BLUE}File:${NC}         $BUILDFLOWZ_SESSION_DIR/session_id"
}

# -----------------------------------------------------------------------------
# get_session_info_for_ssh - Get session info formatted for SSH retrieval
#
# Description:
#   Returns session information in a parseable format for SSH.
#   Used by client scripts to retrieve server session identity.
#
# Arguments:
#   None
#
# Returns:
#   0 - Success
#
# Outputs:
#   SESSION_ID, HASH_ART, and SESSION_CODE separated by markers
#
# Example:
#   ssh server "source lib.sh && get_session_info_for_ssh"
# -----------------------------------------------------------------------------
get_session_info_for_ssh() {
    if [ "$BUILDFLOWZ_SESSION_ENABLED" != "true" ]; then
        echo "SESSION_DISABLED"
        return 1
    fi

    local session_id=$(get_session_id)
    if [ -z "$session_id" ]; then
        echo "SESSION_ERROR"
        return 1
    fi

    local hash_art=$(generate_hash_art "$session_id")
    local session_code=$(get_session_code "$session_id")
    local user="${USER:-unknown}"
    local host="${HOSTNAME:-$(hostname 2>/dev/null || echo 'unknown')}"

    # Output in parseable format
    echo "---SESSION_START---"
    echo "USER:$user"
    echo "HOST:$host"
    echo "CODE:$session_code"
    echo "---HASH_ART_START---"
    echo "$hash_art"
    echo "---HASH_ART_END---"
    echo "---SESSION_END---"
}

# GitHub repo operations
list_github_repos() {
    if ! command -v gh >/dev/null 2>&1; then
        error "GitHub CLI (gh) n'est pas installé"
        info "Installation: apt install gh"
        return 1
    fi

    if ! gh auth status >/dev/null 2>&1; then
        error "Non authentifié sur GitHub"
        info "Authentification: gh auth login"
        return 1
    fi

    gh repo list --limit "$BUILDFLOWZ_GITHUB_REPO_LIMIT" --json name,description --jq '.[] | "\(.name): \(.description)"' 2>/dev/null
}

# Validate GitHub repo name
validate_repo_name() {
    local repo=$1

    if [ -z "$repo" ]; then
        error "Repository name cannot be empty"
        return 1
    fi

    # GitHub repo names: alphanumeric, dash, underscore, dot
    if [[ ! "$repo" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        error "Invalid repository name: $repo"
        return 1
    fi

    return 0
}

get_github_username() {
    gh api user --jq .login 2>/dev/null
}

# Detect project type and return package manager info
detect_project_type() {
    local project_dir=$1
    
    cd "$project_dir" || return 1
    
    if [ -f "package-lock.json" ]; then
        echo "nodejs:npm"
    elif [ -f "pnpm-lock.yaml" ]; then
        echo "nodejs:pnpm"
    elif [ -f "yarn.lock" ]; then
        echo "nodejs:yarn"
    elif [ -f "package.json" ]; then
        echo "nodejs:npm"
    elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
        echo "python:pip"
    elif [ -f "Cargo.toml" ]; then
        echo "rust:cargo"
    elif [ -f "go.mod" ]; then
        echo "go:go"
    else
        echo "generic:none"
    fi
}

# Create or init Flox environment for project
init_flox_env() {
    local project_dir=$1
    local project_name=$2

    log INFO "Initializing Flox environment: $project_name at $project_dir"

    # Check if flox is installed
    if ! command -v flox >/dev/null 2>&1; then
        error "Flox is not installed"
        info "Install with: curl -fsSL https://flox.dev/install | bash"
        return 1
    fi

    cd "$project_dir" || return 1

    if [ -d ".flox" ]; then
        echo -e "${GREEN}✅ Environnement Flox existe déjà${NC}"
        log DEBUG "Flox environment already exists for $project_name"
        return 0
    fi

    echo -e "${BLUE}🔧 Création de l'environnement Flox...${NC}"
    
    # Detect project type
    local project_type=$(detect_project_type "$project_dir")
    local lang=$(echo "$project_type" | cut -d: -f1)
    local pm=$(echo "$project_type" | cut -d: -f2)
    
    echo -e "${BLUE}📦 Type détecté: $lang ($pm)${NC}"
    
    # Init flox environment
    if ! flox init -d "$project_dir" 2>/dev/null; then
        error "Échec de l'initialisation Flox"
        return 1
    fi
    
    # Install packages based on project type
    case "$lang" in
        nodejs)
            echo -e "${BLUE}📦 Installation de Node.js...${NC}"
            flox install nodejs 2>&1 | tail -1
            # Install package manager if needed
            if [ "$pm" = "pnpm" ]; then
                echo -e "${BLUE}📦 Installation de pnpm...${NC}"
                flox install pnpm 2>&1 | tail -1
            elif [ "$pm" = "yarn" ]; then
                echo -e "${BLUE}📦 Installation de yarn...${NC}"
                flox install yarn 2>&1 | tail -1
            fi
            ;;
        python)
            echo -e "${BLUE}🐍 Installation de Python et pip...${NC}"
            flox install python3 python3Packages.pip
            ;;
        rust)
            echo -e "${BLUE}🦀 Installation de Rust...${NC}"
            flox install rustc cargo
            ;;
        go)
            echo -e "${BLUE}🐹 Installation de Go...${NC}"
            flox install go
            ;;
        generic)
            echo -e "${YELLOW}📄 Projet générique - environnement Flox de base${NC}"
            ;;
    esac
    
    # Install project dependencies if needed
    if [ "$lang" = "nodejs" ]; then
        echo -e "${BLUE}📦 Installation des dépendances du projet...${NC}"
        cd "$project_dir"
        if [ "$pm" = "pnpm" ] && [ -f "pnpm-lock.yaml" ]; then
            flox activate -- pnpm install 2>&1 | grep -v "Progress:" || true
        elif [ "$pm" = "yarn" ] && [ -f "yarn.lock" ]; then
            flox activate -- yarn install 2>&1 | grep -v "Progress:" || true
        elif [ -f "package.json" ]; then
            flox activate -- npm install 2>&1 | grep -v "npm WARN" || true
        fi
        echo -e "${GREEN}✅ Dépendances installées${NC}"
    fi
    
    # Fix port configuration in project files
    fix_port_config "$project_dir"
        
    success "Environnement Flox créé pour $project_name"
    return 0
}

# Fix port configuration in project config files
fix_port_config() {
    local project_dir=$1
    
    cd "$project_dir" || return 1
    
    # Astro: astro.config.mjs or astro.config.ts
    if [ -f "astro.config.mjs" ] || [ -f "astro.config.ts" ]; then
        local config_file=""
        [ -f "astro.config.mjs" ] && config_file="astro.config.mjs"
        [ -f "astro.config.ts" ] && config_file="astro.config.ts"
        
        if [ -n "$config_file" ]; then
            echo -e "${BLUE}🔧 Configuration d'Astro pour utiliser PORT...${NC}"
            
            # Check if server config exists with hardcoded port
            if grep -q "server.*:.*{" "$config_file" && grep -q "port.*:.*[0-9]" "$config_file"; then
                # Replace hardcoded port with process.env.PORT or default
                sed -i 's/port: *[0-9]\+/port: parseInt(process.env.PORT) || 3000/' "$config_file"
                echo -e "${GREEN}✅ Configuration Astro mise à jour${NC}"
            elif ! grep -q "server.*:" "$config_file"; then
                # Add server config if not exists
                sed -i '/export default defineConfig({/a\  server: {\n    port: parseInt(process.env.PORT) || 3000\n  },' "$config_file"
                echo -e "${GREEN}✅ Configuration Astro ajoutée${NC}"
            fi
        fi
    fi
    
    # Next.js: next.config.js or next.config.mjs
    if [ -f "next.config.js" ] || [ -f "next.config.mjs" ]; then
        echo -e "${BLUE}ℹ️  Next.js utilise -p pour le port (déjà géré)${NC}"
    fi
    
    # Vite: vite.config.js/ts
    if [ -f "vite.config.js" ] || [ -f "vite.config.ts" ]; then
        local config_file=""
        [ -f "vite.config.js" ] && config_file="vite.config.js"
        [ -f "vite.config.ts" ] && config_file="vite.config.ts"
        
        if [ -n "$config_file" ]; then
            echo -e "${BLUE}🔧 Configuration de Vite pour utiliser PORT...${NC}"
            
            if grep -q "server.*:.*{" "$config_file" && grep -q "port.*:.*[0-9]" "$config_file"; then
                sed -i 's/port: *[0-9]\+/port: parseInt(process.env.PORT) || 3000/' "$config_file"
                # Add HMR configuration if not present
                if ! grep -q "hmr.*:.*{" "$config_file"; then
                    sed -i '/server.*:.*{/a\    hmr: {\n      protocol: '\''ws'\'',\n      host: '\''localhost'\'',\n      port: parseInt(process.env.PORT) || 3000\n    },' "$config_file"
                fi
                echo -e "${GREEN}✅ Configuration Vite mise à jour avec HMR${NC}"
            elif grep -q "export default defineConfig({" "$config_file"; then
                sed -i '/export default defineConfig({/a\  server: {\n    port: parseInt(process.env.PORT) || 3000,\n    host: true,\n    hmr: {\n      protocol: '\''ws'\'',\n      host: '\''localhost'\'',\n      port: parseInt(process.env.PORT) || 3000\n    }\n  },' "$config_file"
                echo -e "${GREEN}✅ Configuration Vite ajoutée avec HMR${NC}"
            fi
        fi
    fi
    
    # Nuxt: nuxt.config.ts
    if [ -f "nuxt.config.ts" ]; then
        echo -e "${BLUE}ℹ️  Nuxt utilise --port pour le port (déjà géré)${NC}"
    fi
}

# Detect dev command for project
detect_dev_command() {
    local project_dir=$1
    local port=$2  # Port à utiliser
    
    cd "$project_dir" || return 1
    
    if [ -f "package.json" ]; then
        # Detect framework from package.json
        local framework=""
        if grep -q '"astro"' package.json; then
            framework="astro"
        elif grep -q '"next"' package.json; then
            framework="next"
        elif grep -q '"vite"' package.json; then
            framework="vite"
        elif grep -q '"nuxt"' package.json; then
            framework="nuxt"
        fi
        
        # Determine package manager
        local pm_cmd=""
        if [ -f "pnpm-lock.yaml" ]; then
            pm_cmd="pnpm"
        elif [ -f "yarn.lock" ]; then
            pm_cmd="yarn"
        else
            pm_cmd="npm run"
        fi
        
        # Build command based on framework and port
        if [ -n "$framework" ]; then
            case "$framework" in
                astro)
                    echo "$pm_cmd dev -- --port \$PORT"
                    ;;
                next)
                    echo "$pm_cmd dev -p \$PORT"
                    ;;
                vite)
                    echo "$pm_cmd dev -- --port \$PORT --host"
                    ;;
                nuxt)
                    echo "$pm_cmd dev --port \$PORT"
                    ;;
                *)
                    echo "$pm_cmd dev"
                    ;;
            esac
        elif grep -q '"dev"' package.json; then
            echo "$pm_cmd dev"
        elif grep -q '"start"' package.json; then
            echo "$pm_cmd start"
        fi
    elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
        if [ -f "manage.py" ]; then
            echo "python manage.py runserver 0.0.0.0:\$PORT"
        elif [ -f "app.py" ]; then
            echo "python app.py"
        else
            echo "python -m http.server \$PORT"
        fi
    elif [ -f "Cargo.toml" ]; then
        echo "cargo run"
    elif [ -f "go.mod" ]; then
        echo "go run ."
    else
        echo "echo 'No dev command detected'"
    fi
}

# ============================================================================
# ENVIRONMENT LIFECYCLE OPERATIONS
# ============================================================================

# -----------------------------------------------------------------------------
# env_start - Start a development environment with PM2 + Flox
#
# Description:
#   Starts a project environment using PM2 for process management and
#   Flox for dependency isolation. Automatically:
#   - Validates identifier
#   - Initializes Flox environment if needed
#   - Detects dev command for project
#   - Allocates/reuses port
#   - Creates PM2 ecosystem config
#   - Injects web inspector
#   - Starts PM2 process
#
# Arguments:
#   $1 - Environment identifier (name or absolute path)
#
# Returns:
#   0 - Environment started successfully
#   1 - Error occurred
#
# Side Effects:
#   - Creates ecosystem.config.cjs in project directory
#   - Invalidates PM2 cache
#   - Kills existing PM2 process if running
#   - May modify vite.config.js or astro.config.mjs for port config
#
# Example:
#   env_start "myapp"
#   env_start "/root/custom/path"
# -----------------------------------------------------------------------------
env_start() {
    local identifier=$1 # Can be env_name or custom_path
    local project_dir=""
    local env_name=""
    local pm2_config=""

    # Validate identifier
    if [ -z "$identifier" ]; then
        error "Environment identifier is required"
        return 1
    fi

    # If it looks like a path, validate it
    if [[ "$identifier" == /* ]]; then
        if ! validate_project_path "$identifier"; then
            return 1
        fi
    else
        if ! validate_env_name "$identifier"; then
            return 1
        fi
    fi

    project_dir=$(resolve_project_path "$identifier")
    if [ -z "$project_dir" ]; then
        error "Projet introuvable pour l'identifiant: $identifier"
        return 1
    fi
    
    env_name=$(basename "$project_dir") # Derive env_name from the resolved path
    pm2_config="$project_dir/ecosystem.config.cjs"

    # Check if Flox env exists, create if not
    if [ ! -d "$project_dir/.flox" ]; then
        echo -e "${YELLOW}⚠️  Pas d'environnement Flox détecté${NC}"
        init_flox_env "$project_dir" "$env_name" || return 1
    fi

    # Detect dev command
    local dev_cmd=$(detect_dev_command "$project_dir")
    
    if [ -z "$dev_cmd" ] || [ "$dev_cmd" = "echo 'No dev command detected'" ]; then
        warning "Aucune commande de dev détectée pour $env_name"
        return 1
    fi

    local port=""
    local doppler_prefix=""
    # Check for existing port and doppler in ecosystem.config.cjs - PROPER PARSING
    if [ -f "$pm2_config" ]; then
        # Use Node.js to properly parse the config file
        local config_data=$(node -e "
            try {
                const cfg = require('$pm2_config');
                const app = cfg.apps[0];
                const port = app.env && app.env.PORT ? app.env.PORT : '';
                const hasDoppler = app.args && Array.isArray(app.args) && app.args.join(' ').includes('doppler run');
                console.log(JSON.stringify({ port: port, hasDoppler: hasDoppler }));
            } catch (e) {
                console.log(JSON.stringify({ port: '', hasDoppler: false }));
            }
        " 2>/dev/null)

        if [ -n "$config_data" ]; then
            port=$(echo "$config_data" | python3 -c "import sys, json; d = json.load(sys.stdin); print(d.get('port', ''))" 2>/dev/null)
            local has_doppler=$(echo "$config_data" | python3 -c "import sys, json; d = json.load(sys.stdin); print('true' if d.get('hasDoppler') else 'false')" 2>/dev/null)
            if [ "$has_doppler" = "true" ]; then
                doppler_prefix="doppler run -- "
            fi
        fi
    fi

    # If no persistent port found, find an available one
    if [ -z "$port" ]; then
        port=$(find_available_port 3000)
        [ -z "$port" ] && return 1
        echo -e "${BLUE}🔌 Nouveau port assigné: $port${NC}"
    else
        echo -e "${BLUE}🔌 Port persistant réutilisé: $port${NC}"
    fi
    
    echo -e "${BLUE}🚀 Commande: $dev_cmd${NC}"
    
    # Replace $PORT in dev_cmd with actual port value
    local final_cmd="${dev_cmd//\$PORT/$port}"
    
    # Create persistent ecosystem file
    cat > "$pm2_config" <<EOF
module.exports = {
  apps: [{
    name: "$env_name",
    cwd: "$project_dir",
    script: "bash",
    args: ["-c", "export PORT=$port && flox activate -- ${doppler_prefix}$final_cmd"],
    env: {
      PORT: $port
    },
    autorestart: true,
    watch: false
  }]
};
EOF
    
    echo -e "${GREEN}✅ Fichier ecosystem.config.cjs créé/mis à jour${NC}"

    # Inject web inspector before starting the dev server
    (cd "$project_dir" && init_web_inspector)

    # Atomic cleanup of existing process (Priority 3 #11: Fix race condition)
    # Use pm2 delete with idempotent operation (no check-then-act)
    pm2 delete "$env_name" 2>/dev/null || true

    # Kill any lingering processes on the port to avoid zombies
    if command -v fuser >/dev/null 2>&1; then
        fuser -k "$port/tcp" 2>/dev/null || true
    fi

    # Small delay to ensure port is fully released
    sleep 0.5
    
    pm2 start "$pm2_config"
    pm2 save >/dev/null 2>&1

    # Invalidate cache after PM2 state change
    invalidate_pm2_cache

    success "Projet $env_name démarré sur le port $port"
    log INFO "Started environment: $env_name on port $port at $project_dir"
}

# -----------------------------------------------------------------------------
# env_stop - Stop a running environment
#
# Description:
#   Stops a PM2-managed environment gracefully.
#
# Arguments:
#   $1 - Environment identifier (name or path)
#
# Returns:
#   0 - Environment stopped or already stopped
#   1 - Error occurred
#
# Side Effects:
#   - Invalidates PM2 cache
#   - Saves PM2 process list
#
# Example:
#   env_stop "myapp"
# -----------------------------------------------------------------------------
env_stop() {
    local identifier=$1

    # Validate identifier
    if [ -z "$identifier" ]; then
        error "Environment identifier is required"
        return 1
    fi

    local project_dir=$(resolve_project_path "$identifier")

    if [ -z "$project_dir" ]; then
        warning "Projet $identifier introuvable ou chemin invalide."
        return 1
    fi

    # Ensure env_name is correctly derived for PM2 operations
    local pm2_app_name=$(basename "$project_dir")

    # Atomic stop operation (Priority 3 #11: Fix race condition)
    # Use pm2 stop with idempotent operation (no check-then-act)
    if pm2 stop "$pm2_app_name" 2>/dev/null; then
        pm2 save >/dev/null 2>&1
        # Invalidate cache after PM2 state change
        invalidate_pm2_cache
        success "Projet $pm2_app_name arrêté"
        log INFO "Stopped environment: $pm2_app_name"
    else
        info "Projet $pm2_app_name n'est pas en cours d'exécution"
        log DEBUG "Environment $pm2_app_name was not running"
    fi

    return 0
}

# Web Inspector Functions
# Generate CSS selector for an element
generate_css_selector() {
    local element="$1"
    echo "css-selector-for-$element" | sed 's/[^a-zA-Z0-9_-]/-/g'
}

# Initialize web inspector
init_web_inspector() {
    local script_path="${SCRIPT_DIR}/injectors/web-inspector.js"

    if [ ! -f "$script_path" ]; then
        echo "Error: Web inspector script not found at $script_path"
        return 1
    fi

    # Step 1: Copy script to project's public/ directory
    mkdir -p public
    cp "$script_path" public/buildflowz-inspector.js
    echo "Copied web inspector to public/buildflowz-inspector.js"

    local script_tag='<script src="/buildflowz-inspector.js" defer></script>'
    local marker="<!-- buildflowz-inspector -->"

    # Step 2: Add script tag to the appropriate file
    if [ -f "index.html" ]; then
        # Vite/React/Vue projects with root index.html
        if ! grep -q "buildflowz-inspector" "index.html"; then
            sed -i "s|</body>|  ${marker}\n  ${script_tag}\n</body>|" "index.html"
            echo "Injected script tag into index.html"
        else
            echo "Script tag already present in index.html"
        fi
    elif [ -f "package.json" ] && grep -q '"astro"' package.json; then
        # Astro projects: inject into layout files
        local injected=false
        for layout in src/layouts/*.astro; do
            [ -f "$layout" ] || continue
            if grep -q "</body>" "$layout" && ! grep -q "buildflowz-inspector" "$layout"; then
                sed -i "s|</body>|  ${marker}\n  ${script_tag}\n</body>|" "$layout"
                echo "Injected script tag into $layout"
                injected=true
            elif grep -q "buildflowz-inspector" "$layout"; then
                echo "Script tag already present in $layout"
                injected=true
            fi
        done
        if [ "$injected" = false ]; then
            echo "Warning: No layout with </body> found for Astro project"
        fi
    else
        echo "Warning: Could not find injection target (no index.html or Astro layout)"
    fi

    echo "Web inspector configured"
}

# -----------------------------------------------------------------------------
# env_remove - Remove an environment completely
#
# Description:
#   Stops the PM2 process and deletes the project directory.
#   This operation is DESTRUCTIVE and cannot be undone.
#
# Arguments:
#   $1 - Environment identifier (name or path)
#
# Returns:
#   0 - Environment removed
#   1 - Error occurred
#
# Side Effects:
#   - Deletes PM2 process
#   - Removes entire project directory (DESTRUCTIVE!)
#   - Invalidates PM2 cache
#
# Warning:
#   This permanently deletes all project files!
#
# Example:
#   env_remove "myapp"
# -----------------------------------------------------------------------------
env_remove() {
    local identifier=$1

    # Validate identifier
    if [ -z "$identifier" ]; then
        error "Environment identifier is required"
        return 1
    fi

    local project_dir=$(resolve_project_path "$identifier")

    if [ -z "$project_dir" ]; then
        warning "Projet $identifier introuvable ou chemin invalide. Impossible de supprimer."
        return 1
    fi

    local env_name=$(basename "$project_dir")

    # Atomic deletion of PM2 process (Priority 3 #11: Fix race condition)
    # Use pm2 delete with idempotent operation (no check-then-act)
    if pm2 delete "$env_name" 2>/dev/null; then
        echo -e "${YELLOW}🛑 Arrêt du processus PM2 $env_name...${NC}"
        pm2 save >/dev/null 2>&1
        # Invalidate cache after PM2 state change
        invalidate_pm2_cache
    fi

    # Remove project directory (atomic operation)
    if [ -d "$project_dir" ]; then
        log INFO "Removing environment: $env_name at $project_dir"
        rm -rf "$project_dir" || {
            error "Failed to remove directory: $project_dir"
            log ERROR "Failed to remove $project_dir"
            return 1
        }
        success "Projet $env_name supprimé"
    else
        warning "Répertoire $project_dir introuvable (peut-être déjà supprimé ou chemin incorrect)"
    fi

    return 0
}

# -----------------------------------------------------------------------------
# show_dashboard - Display comprehensive dashboard with all environments
#
# Description:
#   Shows a unified view combining environment list, ports, status, and URLs.
#   Replaces separate "List environments" and "Show URLs" commands for better UX.
#   Displays local URLs (localhost) and web URLs (DuckDNS) in one view.
#
# Arguments:
#   None
#
# Returns:
#   0 - Success
#   1 - No environments found
#
# Outputs:
#   Formatted dashboard to stdout with environment status, ports, and URLs
#
# Example:
#   show_dashboard
# -----------------------------------------------------------------------------
show_dashboard() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}            ${YELLOW}Environment Dashboard${NC}             ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""

    # Get all environments
    local all_envs=$(list_all_environments)

    if [ -z "$all_envs" ]; then
        echo -e "${YELLOW}⚠️  No environments found${NC}"
        echo ""
        echo -e "${BLUE}💡 Tip: Use 'Start/Deploy' to create a new environment${NC}"
        return 1
    fi

    # Display environments with status
    echo -e "${GREEN}📊 Active Environments:${NC}"
    echo ""

    local count=0
    while IFS= read -r name; do
        ((count++))
        local status=$(get_pm2_status "$name")
        local port=$(get_port_from_pm2 "$name")
        local project_dir=$(resolve_project_path "$name")

        # Status indicator
        local status_icon
        local status_color
        if [ "$status" = "online" ]; then
            status_icon="🟢"
            status_color="${GREEN}"
        elif [ "$status" = "stopped" ]; then
            status_icon="🟡"
            status_color="${YELLOW}"
        elif [ "$status" = "errored" ] || [ "$status" = "error" ]; then
            status_icon="🔴"
            status_color="${RED}"
        else
            status_icon="⚪"
            status_color="${NC}"
        fi

        # Display environment info
        printf "  %s %-20s" "$status_icon" "$name"

        if [ -n "$port" ]; then
            printf "${BLUE}Port: %-6s${NC}" ":$port"
            printf "${CYAN}http://localhost:$port${NC}"
        else
            printf "${YELLOW}No port${NC}"
        fi

        echo ""
    done <<< "$all_envs"

    echo ""
    echo -e "${BLUE}Total: $count environment(s)${NC}"

    # Check for web URLs (Caddyfile)
    if [ -f "/etc/caddy/Caddyfile" ]; then
        echo ""
        echo -e "${GREEN}🌐 Web URLs (HTTPS):${NC}"
        echo ""

        # Parse Caddyfile for domains
        local domains=$(grep -E "^[a-zA-Z0-9\-]+\.duckdns\.org" /etc/caddy/Caddyfile 2>/dev/null | sort -u)

        if [ -n "$domains" ]; then
            while IFS= read -r domain; do
                echo -e "  ${CYAN}https://$domain${NC}"
            done <<< "$domains"
        else
            echo -e "  ${YELLOW}No web URLs configured${NC}"
        fi
    fi

    echo ""
    return 0
}

# -----------------------------------------------------------------------------
# env_restart - Restart an environment
#
# Description:
#   Restarts a PM2 environment in one step (stop + start).
#   Faster than manual stop → start workflow.
#   Invalidates PM2 cache to ensure fresh data.
#
# Arguments:
#   $1 - Environment identifier (name or path)
#
# Returns:
#   0 - Successfully restarted
#   1 - Error occurred
#
# Outputs:
#   Status messages to stdout
#
# Side Effects:
#   - Restarts PM2 process
#   - Invalidates PM2 cache
#   - Saves PM2 state
#
# Example:
#   env_restart "my-app"
#   env_restart "/root/my-app"
# -----------------------------------------------------------------------------
env_restart() {
    local identifier=$1

    if [ -z "$identifier" ]; then
        error "Usage: env_restart <environment-name-or-path>"
        return 1
    fi

    # Resolve project directory
    local project_dir=$(resolve_project_path "$identifier")
    if [ -z "$project_dir" ]; then
        error "Environment not found: $identifier"
        return 1
    fi

    local env_name=$(basename "$project_dir")

    echo -e "${BLUE}🔄 Restarting environment: $env_name${NC}"
    log INFO "Restarting environment: $env_name"

    # Check if environment exists in PM2
    local status=$(get_pm2_status "$env_name")

    if [ "$status" = "not_found" ]; then
        warning "Environment $env_name not running in PM2"
        echo -e "${YELLOW}Starting instead...${NC}"
        env_start "$project_dir"
        return $?
    fi

    # Restart PM2 process (atomic operation)
    if pm2 restart "$env_name" >/dev/null 2>&1; then
        pm2 save >/dev/null 2>&1
        invalidate_pm2_cache

        local port=$(get_port_from_pm2 "$env_name")
        success "Environment $env_name restarted successfully"

        if [ -n "$port" ]; then
            echo -e "${GREEN}✅ URL: ${CYAN}http://localhost:$port${NC}"
        fi

        log INFO "Successfully restarted: $env_name"
        return 0
    else
        error "Failed to restart $env_name"
        log ERROR "Failed to restart: $env_name"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# view_environment_logs - Display PM2 logs for an environment
#
# Description:
#   Shows the last 50 lines of PM2 logs for debugging and monitoring.
#   Useful for troubleshooting errors and checking application output.
#
# Arguments:
#   $1 - Environment identifier (name or path)
#   $2 - Number of lines to show (optional, default: 50)
#
# Returns:
#   0 - Successfully displayed logs
#   1 - Error occurred
#
# Outputs:
#   PM2 logs to stdout
#
# Example:
#   view_environment_logs "my-app"
#   view_environment_logs "my-app" 100
# -----------------------------------------------------------------------------
view_environment_logs() {
    local identifier=$1
    local lines=${2:-50}

    if [ -z "$identifier" ]; then
        error "Usage: view_environment_logs <environment-name-or-path> [lines]"
        return 1
    fi

    # Resolve project directory
    local project_dir=$(resolve_project_path "$identifier")
    if [ -z "$project_dir" ]; then
        error "Environment not found: $identifier"
        return 1
    fi

    local env_name=$(basename "$project_dir")

    # Check if environment exists in PM2
    local status=$(get_pm2_status "$env_name")

    if [ "$status" = "not_found" ]; then
        error "Environment $env_name not found in PM2"
        return 1
    fi

    echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${YELLOW}Logs: $env_name${NC} (last $lines lines)         ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""

    # Display logs
    pm2 logs "$env_name" --lines "$lines" --nostream

    echo ""
    echo -e "${BLUE}💡 Tip: Use Ctrl+C to stop, or 'pm2 logs $env_name' for live tail${NC}"
    echo ""

    return 0
}

# -----------------------------------------------------------------------------
# deploy_github_project - Deploy a project from GitHub repository
#
# Description:
#   Complete workflow to deploy a GitHub repository:
#   - Creates project directory
#   - Clones repository from GitHub
#   - Initializes Flox environment
#   - Starts the application with PM2
#   - Handles existing projects (asks to replace)
#
# Arguments:
#   $1 - Repository name (e.g., "my-repo")
#
# Returns:
#   0 - Successfully deployed
#   1 - Error occurred
#
# Outputs:
#   Progress messages and final URLs to stdout
#
# Side Effects:
#   - Creates directory in PROJECTS_DIR
#   - Clones git repository
#   - Initializes Flox environment
#   - Starts PM2 process
#
# Example:
#   deploy_github_project "my-awesome-app"
# -----------------------------------------------------------------------------
deploy_github_project() {
    local repo_name=$1

    if [ -z "$repo_name" ]; then
        error "Usage: deploy_github_project <repo-name>"
        return 1
    fi

    # Validate repo name
    if ! validate_repo_name "$repo_name"; then
        error "Invalid repository name: $repo_name"
        return 1
    fi

    echo ""
    echo -e "${GREEN}📦 Repository: $repo_name${NC}"
    echo -e "${BLUE}🚀 Starting deployment...${NC}"
    echo ""

    # Project setup
    local project_name="${repo_name,,}"  # lowercase
    local project_dir="$PROJECTS_DIR/$project_name"

    # Check if project already exists
    local existing_project=$(resolve_project_path "$project_name")
    if [ -n "$existing_project" ]; then
        echo -e "${YELLOW}⚠️  Project $project_name already exists at $existing_project${NC}"
        echo -e "${YELLOW}Replace it? (yes/N):${NC} \c"
        read -r confirm

        if [[ ! "$confirm" =~ ^(yes|YES)$ ]]; then
            echo -e "${BLUE}❌ Cancelled${NC}"
            return 1
        fi

        # Remove old project
        echo -e "${YELLOW}Removing old project...${NC}"
        env_remove "$project_name"
    fi

    # Create project directory
    echo -e "${YELLOW}Creating project directory: $project_dir${NC}"
    mkdir -p "$project_dir"

    # Clone repository
    local github_user=$(get_github_username)
    if [ -z "$github_user" ]; then
        error "Could not determine GitHub username"
        rm -rf "$project_dir"
        return 1
    fi

    local repo_url="git@github.com:$github_user/$repo_name.git"
    echo -e "${YELLOW}Cloning (SSH): $repo_url${NC}"
    echo ""

    if git clone "$repo_url" "$project_dir"; then
        echo ""
        echo -e "${GREEN}✅ Repository cloned successfully${NC}"
    else
        echo ""
        echo -e "${RED}❌ Failed to clone repository${NC}"
        echo -e "${YELLOW}Please check:${NC}"
        echo -e "  • Repository exists: https://github.com/$github_user/$repo_name"
        echo -e "  • SSH key is configured: ssh -T git@github.com"
        echo -e "  • Or use: gh auth login --with-token"
        rm -rf "$project_dir"
        return 1
    fi

    # Initialize Flox environment
    echo ""
    echo -e "${YELLOW}🔧 Initializing Flox environment...${NC}"
    if ! init_flox_env "$project_dir" "$project_name"; then
        echo -e "${RED}❌ Flox initialization failed${NC}"
        echo -e "${YELLOW}Cleanup: Removing project directory${NC}"
        rm -rf "$project_dir"
        return 1
    fi

    # Start the environment
    echo ""
    echo -e "${GREEN}🚀 Starting application...${NC}"
    if ! env_start "$project_name"; then
        echo -e "${RED}❌ Failed to start application${NC}"
        echo -e "${YELLOW}Project cloned but not started. Try manually:${NC}"
        echo -e "  cd $project_dir"
        echo -e "  flox activate"
        return 1
    fi

    # Get port and display success
    local port=$(get_port_from_pm2 "$project_name")

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║            ✅ Deployment Successful!             ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}📊 Project Information:${NC}"
    echo -e "  • Name: $project_name"
    echo -e "  • Directory: $project_dir"

    if [ -n "$port" ]; then
        echo -e "  • Port: $port"
        echo ""
        echo -e "${BLUE}🌐 Access URLs:${NC}"
        echo -e "  • Local: ${CYAN}http://localhost:$port${NC}"
    fi

    echo ""
    echo -e "${YELLOW}📝 Next steps:${NC}"
    echo -e "  • View logs: Option 7 → View Logs → Select '$project_name'"
    echo -e "  • Edit code: cd $project_dir"
    echo -e "  • Publish web: Option 6 (Publish to Web)"
    echo ""

    log INFO "Successfully deployed GitHub project: $repo_name"
    return 0
}


