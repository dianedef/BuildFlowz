#!/bin/bash

# BuildFlowz Menu - Unified (Phase 2)
# Single menu file with gum auto-detection and text fallback
# Replaces both menu.sh (gum-only) and menu_simple_color.sh (text-only)

# Load shared library (includes ui_* wrappers, select_environment, etc.)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# Header display
print_header() {
    ui_header "BuildFlowz DevServer" "Development Environment"

    # Display session identity banner if enabled
    if [ "$BUILDFLOWZ_SESSION_ENABLED" = "true" ]; then
        init_session 2>/dev/null
        display_session_banner
        echo ""
    fi
}

# Main menu display
show_menu() {
    echo -e "${BLUE}📊 OVERVIEW${NC}"
    echo -e "  ${CYAN}1)${NC} Dashboard - View all environments at once"
    echo ""
    echo -e "${BLUE}🚀 MANAGE${NC}"
    echo -e "  ${CYAN}2)${NC} Start/Deploy - Launch or deploy environment"
    echo -e "  ${CYAN}3)${NC} Restart - Restart an environment"
    echo -e "  ${CYAN}4)${NC} Stop - Stop an environment"
    echo -e "  ${CYAN}5)${NC} Remove - Delete an environment"
    echo ""
    echo -e "${BLUE}🌐 PUBLISHING${NC}"
    echo -e "  ${CYAN}6)${NC} Publish to Web - Configure HTTPS (Caddy + DuckDNS)"
    echo ""
    echo -e "${BLUE}⚡ BATCH${NC}"
    echo -e "  ${CYAN}7)${NC} Batch Operations - Stop All, Start All, Restart All"
    echo ""
    echo -e "${BLUE}⚙️  ADVANCED${NC}"
    echo -e "  ${CYAN}8)${NC} More Options - Logs, Navigate, Settings..."
    echo ""
    echo -e "${BLUE}📖 DOCUMENTATION${NC}"
    echo -e "  ${CYAN}9)${NC} Help - How BuildFlowz works"
    echo ""
    echo -e "  ${CYAN}0)${NC} Exit"
    echo ""
}

# Help documentation (paginated)
show_help() {
    local page=1
    local total_pages=4

    while true; do
        clear
        echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
        echo -e "              ${YELLOW}BuildFlowz Help${NC} (Page $page/$total_pages)"
        echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
        echo ""

        case $page in
            1)
                echo -e "${GREEN}🚀 QUICKSTART GUIDE${NC}"
                echo ""
                echo -e "${YELLOW}First time? Follow these steps:${NC}"
                echo ""
                echo -e "  ${CYAN}Step 1:${NC} ${GREEN}Have a project ready${NC}"
                echo -e "         Place your project in ${YELLOW}/root/${NC} directory"
                echo -e "         (or clone from GitHub using option 2 → 3)"
                echo ""
                echo -e "  ${CYAN}Step 2:${NC} ${GREEN}Start your project${NC}"
                echo -e "         From main menu, press ${YELLOW}2${NC} (Start/Deploy)"
                echo -e "         Then press ${YELLOW}1${NC} (Auto-detect)"
                echo -e "         Select your project from the list"
                echo ""
                echo -e "  ${CYAN}Step 3:${NC} ${GREEN}Access your app${NC}"
                echo -e "         Your app runs on ${YELLOW}http://localhost:<port>${NC}"
                echo -e "         Check the Dashboard (${YELLOW}1${NC}) to see the port"
                echo ""
                echo -e "  ${CYAN}Step 4:${NC} ${GREEN}Publish to web (optional)${NC}"
                echo -e "         Press ${YELLOW}6${NC} to configure HTTPS with DuckDNS"
                echo ""
                echo -e "${BLUE}┌───────────────────────────────────────────────────────────────┐${NC}"
                echo -e "${BLUE}│${NC} ${YELLOW}Quick Reference:${NC}                                              ${BLUE}│${NC}"
                echo -e "${BLUE}│${NC}   ${CYAN}1${NC} Dashboard  ${CYAN}2${NC} Start  ${CYAN}3${NC} Restart  ${CYAN}4${NC} Stop  ${CYAN}5${NC} Remove      ${BLUE}│${NC}"
                echo -e "${BLUE}│${NC}   ${CYAN}6${NC} Publish    ${CYAN}7${NC} Batch  ${CYAN}8${NC} Advanced ${CYAN}9${NC} Help  ${CYAN}0${NC} Exit        ${BLUE}│${NC}"
                echo -e "${BLUE}└───────────────────────────────────────────────────────────────┘${NC}"
                ;;
            2)
                echo -e "${GREEN}📐 HOW BUILDFLOWZ WORKS${NC}"
                echo ""
                echo -e "${BLUE}┌─────────────────────────────────────────────────────────┐${NC}"
                echo -e "${BLUE}│${NC}  You select a project from the menu                      ${BLUE}│${NC}"
                echo -e "${BLUE}└─────────────────────────────────────────────────────────┘${NC}"
                echo -e "                              ${YELLOW}│${NC}"
                echo -e "                              ${YELLOW}▼${NC}"
                echo -e "${BLUE}┌─────────────────────────────────────────────────────────┐${NC}"
                echo -e "${BLUE}│${NC}  BuildFlowz checks: does project have ${CYAN}.flox${NC} directory?  ${BLUE}│${NC}"
                echo -e "${BLUE}│${NC}  ${GREEN}✓ Yes${NC} → use existing    ${YELLOW}✗ No${NC} → create & configure     ${BLUE}│${NC}"
                echo -e "${BLUE}└─────────────────────────────────────────────────────────┘${NC}"
                echo -e "                              ${YELLOW}│${NC}"
                echo -e "                              ${YELLOW}▼${NC}"
                echo -e "${BLUE}┌─────────────────────────────────────────────────────────┐${NC}"
                echo -e "${BLUE}│${NC}  Auto-detect project type & dev command:                 ${BLUE}│${NC}"
                echo -e "${BLUE}│${NC}  • package.json → ${CYAN}npm/yarn/pnpm dev${NC}                     ${BLUE}│${NC}"
                echo -e "${BLUE}│${NC}  • requirements.txt → ${CYAN}./venv/bin/python main.py${NC}        ${BLUE}│${NC}"
                echo -e "${BLUE}│${NC}  • Cargo.toml → ${CYAN}cargo run${NC}                              ${BLUE}│${NC}"
                echo -e "${BLUE}└─────────────────────────────────────────────────────────┘${NC}"
                echo -e "                              ${YELLOW}│${NC}"
                echo -e "                              ${YELLOW}▼${NC}"
                echo -e "${BLUE}┌─────────────────────────────────────────────────────────┐${NC}"
                echo -e "${BLUE}│${NC}  Create ${CYAN}ecosystem.config.cjs${NC} for PM2:                   ${BLUE}│${NC}"
                echo -e "${BLUE}│${NC}  ${YELLOW}script:${NC} bash -c \"flox activate -- <dev command>\"       ${BLUE}│${NC}"
                echo -e "${BLUE}└─────────────────────────────────────────────────────────┘${NC}"
                echo -e "                              ${YELLOW}│${NC}"
                echo -e "                              ${YELLOW}▼${NC}"
                echo -e "${BLUE}┌─────────────────────────────────────────────────────────┐${NC}"
                echo -e "${BLUE}│${NC}  PM2 manages the process:                                ${BLUE}│${NC}"
                echo -e "${BLUE}│${NC}  ${GREEN}• Auto-restart on crash${NC}                                ${BLUE}│${NC}"
                echo -e "${BLUE}│${NC}  ${GREEN}• Logs captured${NC}                                        ${BLUE}│${NC}"
                echo -e "${BLUE}│${NC}  ${GREEN}• Port management${NC}                                      ${BLUE}│${NC}"
                echo -e "${BLUE}└─────────────────────────────────────────────────────────┘${NC}"
                ;;
            3)
                echo -e "${GREEN}🛠️  SUPPORTED TECHNOLOGIES${NC}"
                echo ""
                echo -e "${BLUE}┌──────────────────┬────────────────────────────────────┐${NC}"
                echo -e "${BLUE}│${NC} ${YELLOW}Language/Stack${NC}   ${BLUE}│${NC} ${YELLOW}Detection & Commands${NC}               ${BLUE}│${NC}"
                echo -e "${BLUE}├──────────────────┼────────────────────────────────────┤${NC}"
                echo -e "${BLUE}│${NC} ${CYAN}Node.js${NC}          ${BLUE}│${NC} package.json                       ${BLUE}│${NC}"
                echo -e "${BLUE}│${NC}                  ${BLUE}│${NC} → npm/yarn/pnpm install & dev      ${BLUE}│${NC}"
                echo -e "${BLUE}├──────────────────┼────────────────────────────────────┤${NC}"
                echo -e "${BLUE}│${NC} ${CYAN}Python${NC}           ${BLUE}│${NC} requirements.txt / pyproject.toml  ${BLUE}│${NC}"
                echo -e "${BLUE}│${NC}                  ${BLUE}│${NC} → venv + pip install + python      ${BLUE}│${NC}"
                echo -e "${BLUE}├──────────────────┼────────────────────────────────────┤${NC}"
                echo -e "${BLUE}│${NC} ${CYAN}Rust${NC}             ${BLUE}│${NC} Cargo.toml                         ${BLUE}│${NC}"
                echo -e "${BLUE}│${NC}                  ${BLUE}│${NC} → cargo run                        ${BLUE}│${NC}"
                echo -e "${BLUE}├──────────────────┼────────────────────────────────────┤${NC}"
                echo -e "${BLUE}│${NC} ${CYAN}Go${NC}               ${BLUE}│${NC} go.mod                             ${BLUE}│${NC}"
                echo -e "${BLUE}│${NC}                  ${BLUE}│${NC} → go run .                         ${BLUE}│${NC}"
                echo -e "${BLUE}└──────────────────┴────────────────────────────────────┘${NC}"
                echo ""
                echo -e "${GREEN}📦 FRAMEWORKS AUTO-DETECTED${NC}"
                echo ""
                echo -e "  ${CYAN}•${NC} Next.js     → ${YELLOW}npm dev -p \$PORT${NC}"
                echo -e "  ${CYAN}•${NC} Astro       → ${YELLOW}npm dev -- --port \$PORT --host${NC}"
                echo -e "  ${CYAN}•${NC} Vite        → ${YELLOW}npm dev -- --port \$PORT --host${NC}"
                echo -e "  ${CYAN}•${NC} Nuxt        → ${YELLOW}npm dev --port \$PORT${NC}"
                echo -e "  ${CYAN}•${NC} Django      → ${YELLOW}python manage.py runserver 0.0.0.0:\$PORT${NC}"
                echo -e "  ${CYAN}•${NC} Flask/FastAPI → ${YELLOW}python app.py${NC} or ${YELLOW}python main.py${NC}"
                echo ""
                echo -e "${GREEN}🔧 ENVIRONMENT ISOLATION${NC}"
                echo ""
                echo -e "  ${CYAN}Flox${NC} provides reproducible, isolated environments"
                echo -e "  Each project gets its own dependencies via Nix"
                ;;
            4)
                echo -e "${GREEN}🔍 WEB INSPECTOR (Visual Selection)${NC}"
                echo ""
                echo -e "  Inject a visual element selector into your web app:"
                echo ""
                echo -e "  ${CYAN}•${NC} Toggle via ${YELLOW}Advanced → Toggle Web Inspector${NC}"
                echo -e "  ${CYAN}•${NC} Shows numbered buttons on every ${YELLOW}<div>${NC} element"
                echo -e "  ${CYAN}•${NC} ${GREEN}Click${NC} → Copy XPath to clipboard"
                echo -e "  ${CYAN}•${NC} ${GREEN}Long-press${NC} → Screenshot menu:"
                echo -e "      - Copy to clipboard"
                echo -e "      - Download PNG"
                echo -e "      - Upload & copy URL (imgbb)"
                echo ""
                echo -e "${GREEN}🖥️  ERUDA CONSOLE${NC}"
                echo ""
                echo -e "  Mobile-friendly developer console injected automatically:"
                echo ""
                echo -e "  ${CYAN}•${NC} View console.log output"
                echo -e "  ${CYAN}•${NC} Inspect network requests"
                echo -e "  ${CYAN}•${NC} View DOM elements"
                echo -e "  ${CYAN}•${NC} Debug JavaScript errors"
                echo -e "  ${CYAN}•${NC} Check storage (localStorage, cookies)"
                echo ""
                echo -e "${YELLOW}💡 Both tools are injected via:${NC}"
                echo -e "   ${CYAN}injectors/web-inspector.js${NC}"
                ;;
        esac

        echo ""
        echo -e "${CYAN}──────────────────────────────────────────────────${NC}"
        echo -e "  ${CYAN}p${NC} Previous   ${CYAN}Enter/n${NC} Next   ${CYAN}1-4${NC} Jump   ${CYAN}0${NC} Back"
        echo -e "${CYAN}──────────────────────────────────────────────────${NC}"
        echo ""
        echo -e "${YELLOW}[$page/$total_pages]:${NC} \c"
        read -r help_choice

        case $help_choice in
            ""|n|N)
                if [ $page -lt $total_pages ]; then
                    page=$((page + 1))
                fi
                ;;
            p|P|b|B)
                if [ $page -gt 1 ]; then
                    page=$((page - 1))
                fi
                ;;
            0|q|Q)
                return
                ;;
            [1-4])
                page=$help_choice
                ;;
        esac
    done
}

# Batch operations submenu
show_batch_menu() {
    while true; do
        clear
        echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
        echo -e "              ${YELLOW}Batch Operations${NC}"
        echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "  ${CYAN}1)${NC} 🛑 Stop All - Stop all environments"
        echo -e "  ${CYAN}2)${NC} 🚀 Start All - Start all environments"
        echo -e "  ${CYAN}3)${NC} 🔄 Restart All - Restart all environments"
        echo ""
        echo -e "  ${CYAN}0)${NC} ← Back to Main Menu"
        echo ""

        echo -e "${YELLOW}Your choice:${NC} \c"
        read -r batch_choice

        case $batch_choice in
            1)
                batch_stop_all
                ;;
            2)
                batch_start_all
                ;;
            3)
                batch_restart_all
                ;;
            0)
                return 0
                ;;
            *)
                echo -e "${RED}❌ Invalid option${NC}"
                ;;
        esac

        echo ""
        echo -e "${YELLOW}Press Enter to continue...${NC}"
        read -r
    done
}

# Submenu "More Options"
show_advanced_menu() {
    while true; do
        clear
        echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
        echo -e "                 ${YELLOW}Advanced Options${NC}"
        echo -e "${CYAN}══════════════════════════════════════════════════${NC}"

        echo -e "${GREEN}Choose an option:${NC}"
        echo ""
        echo -e "  ${CYAN}1)${NC} 📝 View Logs - Display application logs"
        echo -e "  ${CYAN}2)${NC} 📁 Navigate Projects - Browse /root directory"
        echo -e "  ${CYAN}3)${NC} 📂 Open Code Directory - cd into project"
        echo -e "  ${CYAN}4)${NC} 🔍 Toggle Web Inspector - Enable/disable browser inspector"
        echo -e "  ${CYAN}5)${NC} 🔐 Session Identity - View or reset session"
        echo ""
        echo -e "  ${CYAN}0)${NC} ← Back to Main Menu"
        echo ""

        echo -e "${YELLOW}Your choice:${NC} \c"
        read -r adv_choice

        case $adv_choice in
            1)
                # View Logs
                echo -e "${GREEN}📝 View Application Logs${NC}"
                ENV_NAME=$(select_environment "Select environment to view logs")

                if [ -n "$ENV_NAME" ]; then
                    view_environment_logs "$ENV_NAME"
                fi
                ;;
            2)
                # Navigate Projects
                echo -e "${GREEN}📁 Navigate Projects in /root${NC}"
                FOLDERS=$(find /root -maxdepth 1 -type d ! -name ".*" ! -path /root 2>/dev/null | sort)

                if [ -z "$FOLDERS" ]; then
                    echo -e "${RED}❌ No folders found${NC}"
                else
                    SELECTED=$(echo "$FOLDERS" | ui_choose "Available folders:")
                    if [ -n "$SELECTED" ]; then
                        echo -e "${GREEN}📁 Selected folder: $SELECTED${NC}"
                        echo -e "${GREEN}Opening shell...${NC}"
                        cd "$SELECTED" && exec $SHELL
                    fi
                fi
                ;;
            3)
                # Open Code Directory
                echo -e "${GREEN}📂 Open Code Directory${NC}"
                ENV_NAME=$(select_environment "Select environment to open")

                if [ -n "$ENV_NAME" ]; then
                    PROJECT_DIR=$(resolve_project_path "$ENV_NAME")

                    if [ -z "$PROJECT_DIR" ]; then
                        echo -e "${RED}❌ Directory not found: $ENV_NAME${NC}"
                    else
                        echo -e "${GREEN}📂 Project directory: $PROJECT_DIR${NC}"
                        echo -e "${GREEN}Opening shell...${NC}"
                        cd "$PROJECT_DIR" && exec $SHELL
                    fi
                fi
                ;;
            4)
                # Toggle Web Inspector
                echo -e "${GREEN}🔍 Toggle Web Inspector${NC}"
                ENV_NAME=$(select_environment "Select environment for web inspector")

                if [ -n "$ENV_NAME" ]; then
                    PROJECT_DIR=$(resolve_project_path "$ENV_NAME")

                    if [ -z "$PROJECT_DIR" ]; then
                        echo -e "${RED}❌ Project not found: $ENV_NAME${NC}"
                    else
                        log INFO "Menu: toggling web inspector for $ENV_NAME ($PROJECT_DIR)"
                        toggle_web_inspector "$PROJECT_DIR"
                        env_restart "$ENV_NAME"
                    fi
                fi
                ;;
            5)
                # Session Identity Management
                echo -e "${GREEN}🔐 Session Identity Management${NC}"
                echo ""

                display_session_banner
                echo ""
                get_session_info
                echo ""

                echo -e "${BLUE}Options:${NC}"
                echo -e "  ${CYAN}1)${NC} 🔄 Reset Session Identity (generate new pattern)"
                echo -e "  ${CYAN}0)${NC} ← Back"
                echo ""
                echo -e "${YELLOW}Your choice:${NC} \c"
                read -r session_choice

                case $session_choice in
                    1)
                        reset_session
                        echo ""
                        echo -e "${GREEN}New session identity:${NC}"
                        display_session_banner
                        ;;
                    *)
                        ;;
                esac
                ;;
            0)
                return 0
                ;;
            *)
                echo -e "${RED}❌ Invalid option${NC}"
                ;;
        esac

        echo ""
        echo -e "${YELLOW}Press Enter to continue...${NC}"
        read -r
    done
}

# Main function
main() {
    # Check prerequisites on first run
    if ! check_prerequisites; then
        exit 1
    fi

    # Clean up orphan projects at startup
    cleanup_orphan_projects

    while true; do
        clear
        print_header
        show_menu

        echo -e "${YELLOW}Your choice:${NC} \c"
        read -r CHOICE

        case $CHOICE in
            1)
                # Dashboard
                show_dashboard
                ;;

            2)
                # Start/Deploy
                echo -e "${GREEN}🚀 Start/Deploy Environment${NC}"
                echo ""
                echo -e "${BLUE}Choose source:${NC}"
                echo ""
                echo -e "  ${CYAN}1)${NC} 🔍 Auto-detect project in /root"
                echo -e "  ${CYAN}2)${NC} 📁 Custom local path"
                echo -e "  ${CYAN}3)${NC} 🚀 Deploy from GitHub"
                echo -e "  ${CYAN}0)${NC} Cancel"
                echo ""
                echo -e "${YELLOW}Your choice:${NC} \c"
                read -r deploy_choice

                case $deploy_choice in
                    1)
                        # Auto-detect projects
                        echo -e "${BLUE}🔍 Scanning $PROJECTS_DIR for projects...${NC}"

                        EXISTING_ENVS=$(find "$PROJECTS_DIR" -maxdepth 4 -type d -name ".flox" 2>/dev/null | while read -r flox_dir; do
                            proj_dir=$(dirname "$flox_dir")
                            case "$proj_dir" in
                                "$PROJECTS_DIR"/.*) continue ;;
                                *) echo "$proj_dir" ;;
                            esac
                        done | sort -u)

                        NEW_PROJECTS=$(find "$PROJECTS_DIR" -maxdepth 4 -type f \( -name "package.json" -o -name "requirements.txt" -o -name "Cargo.toml" -o -name "go.mod" \) 2>/dev/null | while read -r manifest; do
                            proj_dir=$(dirname "$manifest")
                            case "$proj_dir" in
                                "$PROJECTS_DIR"/.*) continue ;;
                            esac
                            if [ ! -d "$proj_dir/.flox" ]; then
                                echo "$proj_dir"
                            fi
                        done | sort -u)

                        PROJECTS=$(printf "%s\n%s" "$EXISTING_ENVS" "$NEW_PROJECTS" | grep -v "^$" | sort -u)

                        if [ -z "$PROJECTS" ]; then
                            echo -e "${YELLOW}⚠️  No projects detected${NC}"
                            echo -e "${BLUE}💡 Tip: Use option 2 for custom path or option 3 for GitHub${NC}"
                        else
                            SELECTED_PROJECT=$(echo "$PROJECTS" | ui_choose "Detected projects:")
                            if [ -n "$SELECTED_PROJECT" ]; then
                                log INFO "Menu: starting project $SELECTED_PROJECT"
                                echo -e "${GREEN}✅ Starting: $SELECTED_PROJECT${NC}"
                                env_start "$SELECTED_PROJECT"
                            fi
                        fi
                        ;;
                    2)
                        # Custom path
                        CUSTOM_PATH=$(ui_input "Path (absolute):" "/root/my-project")

                        if [ -z "$CUSTOM_PATH" ]; then
                            echo -e "${RED}❌ Path required${NC}"
                        elif ! validate_project_path "$CUSTOM_PATH"; then
                            echo -e "${RED}❌ Invalid or unsafe path${NC}"
                        else
                            env_start "$CUSTOM_PATH"
                        fi
                        ;;
                    3)
                        # Deploy from GitHub
                        echo -e "${GREEN}🚀 Deploy from GitHub${NC}"
                        echo ""
                        echo -e "${BLUE}🔍 Fetching your GitHub repos...${NC}"
                        echo ""

                        GITHUB_REPOS=$(list_github_repos)

                        if [ -z "$GITHUB_REPOS" ]; then
                            continue
                        fi

                        SELECTED_REPO=$(echo "$GITHUB_REPOS" | cut -d':' -f1 | ui_choose "Available repos:")

                        if [ -n "$SELECTED_REPO" ]; then
                            if ! validate_repo_name "$SELECTED_REPO"; then
                                echo -e "${RED}❌ Invalid repository name${NC}"
                                continue
                            fi

                            echo ""
                            echo -e "${GREEN}📦 Selected repo: $SELECTED_REPO${NC}"
                            echo -e "${BLUE}🚀 Deploying...${NC}"
                            echo ""

                            deploy_github_project "$SELECTED_REPO"
                        fi
                        ;;
                    0)
                        echo -e "${BLUE}Cancelled${NC}"
                        ;;
                    *)
                        echo -e "${RED}❌ Invalid option${NC}"
                        ;;
                esac
                ;;

            3)
                # Restart
                echo -e "${GREEN}🔄 Restart Environment${NC}"
                ENV_NAME=$(select_environment "Select environment to restart")

                if [ -n "$ENV_NAME" ]; then
                    log INFO "Menu: restarting $ENV_NAME"
                    env_restart "$ENV_NAME"
                fi
                ;;

            4)
                # Stop
                echo -e "${GREEN}🛑 Stop Environment${NC}"
                ENV_NAME=$(select_environment "Select environment to stop")

                if [ -n "$ENV_NAME" ]; then
                    log INFO "Menu: stopping $ENV_NAME"
                    echo -e "${YELLOW}🛑 Stopping $ENV_NAME...${NC}"
                    env_stop "$ENV_NAME"
                    echo -e "${GREEN}✅ Environment $ENV_NAME stopped!${NC}"
                fi
                ;;

            5)
                # Remove
                echo -e "${GREEN}🗑️  Remove Environment${NC}"
                echo ""
                echo -e "${YELLOW}⚠️  WARNING: This will permanently delete the project!${NC}"
                echo ""
                ENV_NAME=$(select_environment "Select environment to remove")

                if [ -n "$ENV_NAME" ]; then
                    PROJECT_DIR=$(resolve_project_path "$ENV_NAME")

                    echo ""
                    echo -e "${RED}⚠️  You are about to delete:${NC}"
                    echo -e "${YELLOW}   Environment: $ENV_NAME${NC}"
                    echo -e "${YELLOW}   Directory: $PROJECT_DIR${NC}"
                    echo ""

                    if ui_confirm "Type 'yes' to confirm deletion"; then
                        log INFO "Menu: removing environment $ENV_NAME (dir: $PROJECT_DIR)"
                        env_remove "$ENV_NAME"
                        echo -e "${GREEN}✅ Environment removed!${NC}"
                    else
                        echo -e "${BLUE}Cancelled - nothing was deleted${NC}"
                    fi
                fi
                ;;

            6)
                # Publish to Web with credential cache
                echo -e "${GREEN}🌐 Publish to Web (HTTPS via Caddy + DuckDNS)${NC}"
                echo ""

                # Check if Caddy is installed
                if ! command -v caddy >/dev/null 2>&1; then
                    echo -e "${RED}❌ Caddy not installed${NC}"
                    echo -e "${YELLOW}Install with: sudo apt install caddy${NC}"
                    continue
                fi

                # Get public IP
                echo -e "${BLUE}📡 Detecting public IP...${NC}"
                PUBLIC_IP=$(curl -4 -s https://ip.me 2>/dev/null)
                if [ -n "$PUBLIC_IP" ]; then
                    echo -e "${BLUE}📡 Detected Public IP: ${GREEN}$PUBLIC_IP${NC}"
                else
                    echo -e "${YELLOW}⚠️  Could not detect public IP${NC}"
                    PUBLIC_IP=$(ui_input "Enter public IP:")
                fi

                echo ""

                # Try loading cached credentials
                CACHED_SUBDOMAIN=$(load_secret "DUCKDNS_SUBDOMAIN" 2>/dev/null) || true
                CACHED_TOKEN=$(load_secret "DUCKDNS_TOKEN" 2>/dev/null) || true

                if [ -n "$CACHED_SUBDOMAIN" ] && [ -n "$CACHED_TOKEN" ]; then
                    echo -e "${GREEN}📋 Cached subdomain: ${CYAN}$CACHED_SUBDOMAIN${NC}"
                    if ui_confirm "Use cached DuckDNS credentials?"; then
                        DUCKDNS_SUBDOMAIN="$CACHED_SUBDOMAIN"
                        DUCKDNS_TOKEN="$CACHED_TOKEN"
                    else
                        CACHED_SUBDOMAIN=""
                        CACHED_TOKEN=""
                    fi
                fi

                # Prompt if no cached credentials
                if [ -z "$CACHED_SUBDOMAIN" ] || [ -z "$CACHED_TOKEN" ]; then
                    DUCKDNS_SUBDOMAIN=$(ui_input "DuckDNS Subdomain (without .duckdns.org):" "my-subdomain")

                    if [ -z "$DUCKDNS_SUBDOMAIN" ]; then
                        echo -e "${RED}❌ Subdomain required${NC}"
                        continue
                    fi

                    DUCKDNS_TOKEN=$(ui_input "DuckDNS Token:" "your-token-here" "--password")

                    if [ -z "$DUCKDNS_TOKEN" ]; then
                        echo -e "${RED}❌ Token required${NC}"
                        continue
                    fi

                    # Save credentials for next time
                    save_secret "DUCKDNS_SUBDOMAIN" "$DUCKDNS_SUBDOMAIN"
                    save_secret "DUCKDNS_TOKEN" "$DUCKDNS_TOKEN"
                fi

                # Update DuckDNS
                echo ""
                echo -e "${BLUE}🌐 Updating DuckDNS...${NC}"
                DUCKDNS_RESPONSE=$(curl -s "https://www.duckdns.org/update?domains=$DUCKDNS_SUBDOMAIN&token=$DUCKDNS_TOKEN&ip=$PUBLIC_IP")

                if [ "$DUCKDNS_RESPONSE" = "OK" ]; then
                    log INFO "DuckDNS updated: $DUCKDNS_SUBDOMAIN → $PUBLIC_IP"
                    echo -e "${GREEN}✅ DuckDNS updated successfully${NC}"
                else
                    log ERROR "DuckDNS update failed for $DUCKDNS_SUBDOMAIN: $DUCKDNS_RESPONSE"
                    echo -e "${RED}❌ DuckDNS update failed: $DUCKDNS_RESPONSE${NC}"
                    continue
                fi

                # Select environment
                echo ""
                ENV_NAME=$(select_environment "Select environment to publish")

                if [ -z "$ENV_NAME" ]; then
                    continue
                fi

                PORT=$(get_port_from_pm2 "$ENV_NAME")
                if [ -z "$PORT" ]; then
                    echo -e "${RED}❌ Could not get port for $ENV_NAME${NC}"
                    continue
                fi

                # Generate Caddyfile
                DOMAIN="${DUCKDNS_SUBDOMAIN}.duckdns.org"
                CADDYFILE="/etc/caddy/Caddyfile"

                # Backup existing Caddyfile
                if [ -f "$CADDYFILE" ]; then
                    sudo cp "$CADDYFILE" "${CADDYFILE}.backup.$(date +%s)" 2>/dev/null
                fi

                echo -e "${BLUE}🔧 Generating Caddyfile with all online environments...${NC}"

                # Build reverse_proxy routes for ALL online environments with ports
                ROUTES=""
                ALL_ENVS=$(list_all_environments)
                SELECTED_INCLUDED=false
                if [ -n "$ALL_ENVS" ]; then
                    while IFS= read -r env; do
                        [ -z "$env" ] && continue
                        local env_status=$(get_pm2_status "$env")
                        local env_port=$(get_port_from_pm2 "$env")
                        if [ "$env_status" = "online" ] && [ -n "$env_port" ]; then
                            ROUTES="${ROUTES}    reverse_proxy /${env}* localhost:${env_port}"$'\n'
                            echo -e "  ${GREEN}✓${NC} /${env} → localhost:${env_port}"
                            if [ "$env" = "$ENV_NAME" ]; then
                                SELECTED_INCLUDED=true
                            fi
                        fi
                    done <<< "$ALL_ENVS"
                fi

                # Also include the selected environment even if not yet online
                if [ "$SELECTED_INCLUDED" = "false" ]; then
                    ROUTES="${ROUTES}    reverse_proxy /${ENV_NAME}* localhost:${PORT}"$'\n'
                    echo -e "  ${GREEN}✓${NC} /${ENV_NAME} → localhost:${PORT} (selected)"
                fi

                sudo tee "$CADDYFILE" > /dev/null << EOF
${DOMAIN} {
${ROUTES}    encode gzip
}
EOF

                log INFO "Caddyfile generated for $DOMAIN with routes for all online environments"
                echo -e "${GREEN}✅ Caddyfile generated with all routes${NC}"

                # Reload Caddy
                echo -e "${BLUE}🔄 Reloading Caddy...${NC}"
                if sudo systemctl reload caddy; then
                    log INFO "Caddy reloaded successfully for $DOMAIN"
                    echo -e "${GREEN}✅ Caddy reloaded${NC}"
                    echo ""
                    echo -e "${GREEN}🎉 SUCCESS! Published URLs:${NC}"
                    # Show all published routes
                    if [ -n "$ALL_ENVS" ]; then
                        while IFS= read -r env; do
                            [ -z "$env" ] && continue
                            local env_s=$(get_pm2_status "$env")
                            local env_p=$(get_port_from_pm2 "$env")
                            if [ "$env_s" = "online" ] && [ -n "$env_p" ]; then
                                echo -e "${CYAN}   https://$DOMAIN/$env${NC}"
                            fi
                        done <<< "$ALL_ENVS"
                    fi
                    # Ensure selected env is shown
                    if ! echo "$ALL_ENVS" | grep -q "^${ENV_NAME}$" || [ "$(get_pm2_status "$ENV_NAME")" != "online" ]; then
                        echo -e "${CYAN}   https://$DOMAIN/$ENV_NAME${NC} (selected)"
                    fi
                    echo ""
                else
                    log ERROR "Failed to reload Caddy for $DOMAIN"
                    echo -e "${RED}❌ Failed to reload Caddy${NC}"
                    echo -e "${YELLOW}Check logs with: sudo journalctl -u caddy -n 50${NC}"
                fi
                ;;

            7)
                # Batch Operations
                show_batch_menu
                ;;

            8)
                # Advanced Options Submenu
                show_advanced_menu
                ;;

            9)
                # Help
                show_help
                ;;

            0|10)
                echo -e "${GREEN}👋 Goodbye!${NC}"
                exit 0
                ;;

            *)
                echo -e "${RED}❌ Invalid option${NC}"
                ;;
        esac

        echo ""
        echo -e "${YELLOW}Press Enter to continue...${NC}"
        read -r
    done
}

# Launch menu
main
