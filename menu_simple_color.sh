#!/bin/bash

# BuildFlowz Menu - Streamlined UX (Phase 1)
# Reduced from 10 options to 7 for better usability

# Load shared library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# Fonction d'affichage avec couleurs
print_header() {
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "               ${YELLOW}BuildFlowz DevServer${NC}"
    echo -e "             ${BLUE}Development Environment${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"

    # Display session identity banner if enabled
    if [ "$BUILDFLOWZ_SESSION_ENABLED" = "true" ]; then
        init_session 2>/dev/null
        display_session_banner
        echo ""
    fi
}

# Fonction d'affichage du menu
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
    echo -e "${BLUE}⚙️  ADVANCED${NC}"
    echo -e "  ${CYAN}7)${NC} More Options - Logs, Navigate, Settings..."
    echo ""
    echo -e "${BLUE}📖 DOCUMENTATION${NC}"
    echo -e "  ${CYAN}8)${NC} Help - How BuildFlowz works"
    echo ""
    echo -e "  ${CYAN}0)${NC} Exit"
    echo ""
}

# Help documentation
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
                # Quickstart guide
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
                echo -e "${BLUE}┌─────────────────────────────────────────────────────────┐${NC}"
                echo -e "${BLUE}│${NC} ${YELLOW}Quick Reference:${NC}                                        ${BLUE}│${NC}"
                echo -e "${BLUE}│${NC}   ${CYAN}1${NC} Dashboard    ${CYAN}2${NC} Start    ${CYAN}3${NC} Restart   ${CYAN}4${NC} Stop       ${BLUE}│${NC}"
                echo -e "${BLUE}│${NC}   ${CYAN}5${NC} Remove       ${CYAN}6${NC} Publish  ${CYAN}7${NC} Advanced  ${CYAN}8${NC} Help       ${BLUE}│${NC}"
                echo -e "${BLUE}└─────────────────────────────────────────────────────────┘${NC}"
                ;;
            2)
                # Architecture diagram
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
                # Supported technologies
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
                # Web inspector & Eruda
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
        echo -e "  ${CYAN}←${NC} Previous    ${CYAN}→${NC} Next    ${CYAN}0${NC} Back to Menu"
        echo -e "${CYAN}──────────────────────────────────────────────────${NC}"
        echo ""
        echo -e "${YELLOW}Your choice:${NC} \c"
        read -r help_choice

        case $help_choice in
            ""|"n"|"N"|"→"|">")
                if [ $page -lt $total_pages ]; then
                    page=$((page + 1))
                fi
                ;;
            "p"|"P"|"←"|"<")
                if [ $page -gt 1 ]; then
                    page=$((page - 1))
                fi
                ;;
            0)
                return
                ;;
            [1-4])
                page=$help_choice
                ;;
        esac
    done
}

# Fonction de sélection d'environnement
# Note: Display output goes to stderr so command substitution captures only the result
select_environment() {
    local prompt_text="${1:-Sélectionnez un environnement}"

    ALL_ENVS=$(list_all_environments)

    if [ -z "$ALL_ENVS" ]; then
        echo -e "${RED}❌ Aucun environnement trouvé${NC}" >&2
        return 1
    fi

    echo -e "${BLUE}$prompt_text :${NC}" >&2
    echo "" >&2

    i=1
    while IFS= read -r env; do
        echo -e "  ${CYAN}$i)${NC} $env" >&2
        ((i++))
    done <<< "$ALL_ENVS"

    echo "" >&2
    echo -e "  ${CYAN}0)${NC} Annuler" >&2
    echo "" >&2
    echo -e "${YELLOW}Choisissez un numéro (0-$((i-1))) :${NC} \c" >&2
    read -r choice

    if [[ "$choice" == "0" ]]; then
        return 1
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le $((i-1)) ]; then
        echo "$ALL_ENVS" | sed -n "${choice}p"
        return 0
    else
        echo -e "${RED}❌ Choix invalide${NC}" >&2
        return 1
    fi
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
                FOLDERS=$(find /root -maxdepth 1 -type d ! -name ".*" ! -path /root | sort)

                if [ -z "$FOLDERS" ]; then
                    echo -e "${RED}❌ No folders found${NC}"
                else
                    echo -e "${BLUE}Available folders:${NC}"
                    echo ""
                    i=1
                    while IFS= read -r folder; do
                        echo -e "  ${CYAN}$i)${NC} $folder"
                        ((i++))
                    done <<< "$FOLDERS"
                    echo ""
                    echo -e "${YELLOW}Choose a number (1-$((i-1))) :${NC} \c"
                    read -r choice

                    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le $((i-1)) ]; then
                        SELECTED=$(echo "$FOLDERS" | sed -n "${choice}p")
                        echo -e "${GREEN}📁 Selected folder: $SELECTED${NC}"
                        echo -e "${CYAN}Command: cd $SELECTED${NC}"
                        echo -e "${GREEN}Opening shell...${NC}"
                        cd "$SELECTED" && exec $SHELL
                    else
                        echo -e "${RED}❌ Invalid choice${NC}"
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
                        toggle_web_inspector "$PROJECT_DIR"
                        env_restart "$ENV_NAME"
                    fi
                fi
                ;;
            5)
                # Session Identity Management
                echo -e "${GREEN}🔐 Session Identity Management${NC}"
                echo ""

                # Display current session
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
                        echo ""
                        echo -e "${YELLOW}⚠️  This will generate a new session identity.${NC}"
                        echo -e "${YELLOW}Your hash art pattern and code will change.${NC}"
                        echo ""
                        echo -e "${YELLOW}Continue? (yes/N):${NC} \c"
                        read -r confirm

                        if [[ "$confirm" =~ ^(yes|YES)$ ]]; then
                            reset_session
                            echo ""
                            echo -e "${GREEN}New session identity:${NC}"
                            display_session_banner
                        else
                            echo -e "${BLUE}Cancelled${NC}"
                        fi
                        ;;
                    *)
                        ;;
                esac
                ;;
            0)
                # Return to main menu
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

# Fonction principale
main() {
    # Check prerequisites on first run
    if ! check_prerequisites; then
        exit 1
    fi

    # Nettoyer les projets orphelins au démarrage
    cleanup_orphan_projects

    while true; do
        clear
        print_header
        show_menu

        echo -e "${YELLOW}Your choice:${NC} \c"
        read -r CHOICE

        case $CHOICE in
            1)
                # Dashboard - View all environments
                show_dashboard
                ;;

            2)
                # Start/Deploy - Smart start with multiple options
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

                        # First: detect existing BuildFlowz environments (have .flox directory)
                        # Exclude hidden directories (except .flox itself)
                        EXISTING_ENVS=$(find "$PROJECTS_DIR" -maxdepth 4 -type d -name ".flox" 2>/dev/null | while read -r flox_dir; do
                            proj_dir=$(dirname "$flox_dir")
                            # Skip if project is inside a hidden directory (e.g., .cache, .config)
                            case "$proj_dir" in
                                "$PROJECTS_DIR"/.*) continue ;;
                                *) echo "$proj_dir" ;;
                            esac
                        done | sort -u)

                        # Second: detect new projects (have manifest files but no .flox yet)
                        # Exclude hidden directories
                        NEW_PROJECTS=$(find "$PROJECTS_DIR" -maxdepth 4 -type f \( -name "package.json" -o -name "requirements.txt" -o -name "Cargo.toml" -o -name "go.mod" \) 2>/dev/null | while read -r manifest; do
                            proj_dir=$(dirname "$manifest")
                            # Skip if inside a hidden directory
                            case "$proj_dir" in
                                "$PROJECTS_DIR"/.*) continue ;;
                            esac
                            # Only include if NOT already a BuildFlowz environment
                            if [ ! -d "$proj_dir/.flox" ]; then
                                echo "$proj_dir"
                            fi
                        done | sort -u)

                        # Combine both lists (existing first, then new)
                        PROJECTS=$(printf "%s\n%s" "$EXISTING_ENVS" "$NEW_PROJECTS" | grep -v "^$" | sort -u)

                        if [ -z "$PROJECTS" ]; then
                            echo -e "${YELLOW}⚠️  No projects detected${NC}"
                            echo -e "${BLUE}💡 Tip: Use option 2 for custom path or option 3 for GitHub${NC}"
                        else
                            echo -e "${BLUE}Detected projects:${NC}"
                            echo ""
                            i=1
                            while IFS= read -r project; do
                                echo -e "  ${CYAN}$i)${NC} $project"
                                ((i++))
                            done <<< "$PROJECTS"
                            echo ""
                            echo -e "${YELLOW}Choose project (1-$((i-1))):${NC} \c"
                            read -r proj_choice

                            if [[ "$proj_choice" =~ ^[0-9]+$ ]] && [ "$proj_choice" -ge 1 ] && [ "$proj_choice" -le $((i-1)) ]; then
                                SELECTED_PROJECT=$(echo "$PROJECTS" | sed -n "${proj_choice}p")
                                echo -e "${GREEN}✅ Starting: $SELECTED_PROJECT${NC}"
                                env_start "$SELECTED_PROJECT"
                            else
                                echo -e "${RED}❌ Invalid choice${NC}"
                            fi
                        fi
                        ;;
                    2)
                        # Custom path
                        echo -e "${BLUE}📁 Enter project path:${NC}"
                        echo -e "${YELLOW}Path (absolute):${NC} \c"
                        read -r CUSTOM_PATH

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

                        echo -e "${GREEN}Available repos:${NC}"
                        echo ""
                        i=1
                        while IFS= read -r repo; do
                            echo -e "  ${CYAN}$i)${NC} $repo"
                            ((i++))
                        done <<< "$GITHUB_REPOS"
                        echo ""
                        echo -e "${YELLOW}Choose repo (1-$((i-1))):${NC} \c"
                        read -r repo_choice

                        if [[ "$repo_choice" =~ ^[0-9]+$ ]] && [ "$repo_choice" -ge 1 ] && [ "$repo_choice" -le $((i-1)) ]; then
                            SELECTED_REPO=$(echo "$GITHUB_REPOS" | sed -n "${repo_choice}p" | cut -d':' -f1)

                            # Validate repo name
                            if ! validate_repo_name "$SELECTED_REPO"; then
                                echo -e "${RED}❌ Invalid repository name${NC}"
                                continue
                            fi

                            echo ""
                            echo -e "${GREEN}📦 Selected repo: $SELECTED_REPO${NC}"
                            echo -e "${BLUE}🚀 Deploying...${NC}"
                            echo ""

                            # Deploy project
                            deploy_github_project "$SELECTED_REPO"
                        else
                            echo -e "${RED}❌ Invalid choice${NC}"
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
                # Restart Environment
                echo -e "${GREEN}🔄 Restart Environment${NC}"
                ENV_NAME=$(select_environment "Select environment to restart")

                if [ -n "$ENV_NAME" ]; then
                    env_restart "$ENV_NAME"
                fi
                ;;

            4)
                # Stop Environment
                echo -e "${GREEN}🛑 Stop Environment${NC}"
                ENV_NAME=$(select_environment "Select environment to stop")

                if [ -n "$ENV_NAME" ]; then
                    echo -e "${YELLOW}🛑 Stopping $ENV_NAME...${NC}"
                    env_stop "$ENV_NAME"
                    echo -e "${GREEN}✅ Environment $ENV_NAME stopped!${NC}"
                fi
                ;;

            5)
                # Remove Environment
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
                    echo -e "${YELLOW}Type 'yes' to confirm:${NC} \c"
                    read -r confirm

                    if [ "$confirm" = "yes" ]; then
                        env_remove "$ENV_NAME"
                        echo -e "${GREEN}✅ Environment removed!${NC}"
                    else
                        echo -e "${BLUE}Cancelled - nothing was deleted${NC}"
                    fi
                fi
                ;;

            6)
                # Publish to Web
                echo -e "${GREEN}🌐 Publish to Web (HTTPS via Caddy + DuckDNS)${NC}"
                echo ""

                # Check if Caddy is installed
                if ! command -v caddy >/dev/null 2>&1; then
                    echo -e "${RED}❌ Caddy not installed${NC}"
                    echo -e "${YELLOW}Install with: sudo apt install caddy${NC}"
                    continue
                fi

                # Get public IP
                PUBLIC_IP=$(get_public_ip)
                if [ -n "$PUBLIC_IP" ]; then
                    echo -e "${BLUE}📡 Detected Public IP: ${GREEN}$PUBLIC_IP${NC}"
                else
                    echo -e "${YELLOW}⚠️  Could not detect public IP${NC}"
                    echo -e "${YELLOW}IP:${NC} \c"
                    read -r PUBLIC_IP
                fi

                echo ""
                echo -e "${YELLOW}DuckDNS Subdomain (without .duckdns.org):${NC} \c"
                read -r DUCKDNS_SUBDOMAIN

                if [ -z "$DUCKDNS_SUBDOMAIN" ]; then
                    echo -e "${RED}❌ Subdomain required${NC}"
                    continue
                fi

                echo -e "${YELLOW}DuckDNS Token:${NC} \c"
                read -rs DUCKDNS_TOKEN
                echo ""

                if [ -z "$DUCKDNS_TOKEN" ]; then
                    echo -e "${RED}❌ Token required${NC}"
                    continue
                fi

                # Update DuckDNS
                echo ""
                echo -e "${BLUE}🌐 Updating DuckDNS...${NC}"
                DUCKDNS_RESPONSE=$(curl -s "https://www.duckdns.org/update?domains=$DUCKDNS_SUBDOMAIN&token=$DUCKDNS_TOKEN&ip=$PUBLIC_IP")

                if [ "$DUCKDNS_RESPONSE" = "OK" ]; then
                    echo -e "${GREEN}✅ DuckDNS updated successfully${NC}"
                else
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

                echo -e "${BLUE}🔧 Generating Caddyfile...${NC}"

                sudo tee "$CADDYFILE" > /dev/null << EOF
$DOMAIN {
    reverse_proxy /$ENV_NAME* localhost:$PORT
    encode gzip
}
EOF

                echo -e "${GREEN}✅ Caddyfile generated${NC}"

                # Reload Caddy
                echo -e "${BLUE}🔄 Reloading Caddy...${NC}"
                if sudo systemctl reload caddy; then
                    echo -e "${GREEN}✅ Caddy reloaded${NC}"
                    echo ""
                    echo -e "${GREEN}🎉 SUCCESS! Your app is now available at:${NC}"
                    echo -e "${CYAN}   https://$DOMAIN/$ENV_NAME${NC}"
                    echo ""
                else
                    echo -e "${RED}❌ Failed to reload Caddy${NC}"
                    echo -e "${YELLOW}Check logs with: sudo journalctl -u caddy -n 50${NC}"
                fi
                ;;

            7)
                # Advanced Options Submenu
                show_advanced_menu
                ;;

            8)
                # Help documentation
                show_help
                ;;

            0|10)
                # Exit
                echo -e "${GREEN}👋 Au revoir !${NC}"
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

# Lancer le menu
main
