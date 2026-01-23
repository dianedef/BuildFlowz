#!/bin/bash

# Shared library for Dokploy CLI
# Contains all reusable functions and logic

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Config
PROJECTS_DIR="/root"

# Helper functions
success() {
    echo -e "${GREEN}✅${NC} $1"
}

error() {
    echo -e "${RED}❌${NC} $1"
}

info() {
    echo -e "${BLUE}ℹ️${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

# Port management
is_port_in_use() {
    local port=$1
    ss -ltn 2>/dev/null | awk '{print $4}' | grep -E "[:.]${port}$" >/dev/null 2>&1
}

# Get all ports used by PM2 apps (even stopped ones)
get_all_pm2_ports() {
    if ! command -v pm2 >/dev/null 2>&1; then
        return 0
    fi
    
    pm2 jlist 2>/dev/null | python3 -c "
import sys, json
try:
    apps = json.load(sys.stdin)
    ports = []
    for app in apps:
        env_vars = app.get('pm2_env', {}).get('env', {})
        port = env_vars.get('PORT', '')
        if port:
            ports.append(str(port))
    print(' '.join(ports))
except:
    pass
" 2>/dev/null
}

find_available_port() {
    local base_port=$1
    local max_range=100
    local port=$base_port
    
    # Get all ports already assigned in PM2
    local pm2_ports=$(get_all_pm2_ports)
    
    while [ $((port - base_port)) -lt $max_range ]; do
        # Check if port is in use OR already assigned in PM2
        if ! is_port_in_use $port && ! echo "$pm2_ports" | grep -q "\<$port\>"; then
            echo $port
            return 0
        fi
        port=$((port + 1))
    done
    
    echo -e "${RED}❌ Impossible de trouver un port disponible après $max_range tentatives${NC}" >&2
    return 1
}

# Get project status from PM2
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
    
    # Vérifie si le projet existe dans PM2
    if pm2 jlist 2>/dev/null | grep -q "\"name\":\"$env_name\""; then
        # Récupère le statut
        local status=$(pm2 jlist 2>/dev/null | python3 -c "import sys, json; apps = json.load(sys.stdin); print([a['pm2_env']['status'] for a in apps if a['name'] == '$env_name'][0] if any(a['name'] == '$env_name' for a in apps) else 'unknown')" 2>/dev/null)
        echo "${status:-unknown}"
        return 0
    else
        echo "stopped"
        return 0
    fi
}

# Get project directory path


# Get port from PM2 env vars for a project
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
    
    pm2 jlist 2>/dev/null | python3 -c "
import sys, json
try:
    apps = json.load(sys.stdin)
    for app in apps:
        if app['name'] == '$env_name':
            env_vars = app.get('pm2_env', {}).get('env', {})
            port = env_vars.get('PORT', '')
            if port:
                print(port)
                sys.exit(0)
except:
    pass
" 2>/dev/null
}


# Resolve project path from an identifier (env_name or full_path)
resolve_project_path() {
    local identifier=$1

    # Case 1: Identifier is already an absolute path
    if [[ "$identifier" == /* && -d "$identifier" && -d "$identifier/.flox" ]]; then
        echo "$identifier"
        return 0
    fi

    # Case 2: Identifier is an environment name, search within PROJECTS_DIR
    local found_path
    found_path=$(find "$PROJECTS_DIR" -maxdepth 3 -type d -name "$identifier" 2>/dev/null | while read -r project_dir; do
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
        find "$PROJECTS_DIR" -maxdepth 3 -type d -name ".flox" 2>/dev/null | while read -r flox_dir; do
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

# GitHub repo operations
list_github_repos() {
    if ! command -v gh >/dev/null 2>&1; then
        error "GitHub CLI (gh) n'est pas installé"
        echo -e "${YELLOW}Installation :${NC} apt install gh"
        return 1
    fi
    
    if ! gh auth status >/dev/null 2>&1; then
        error "Non authentifié sur GitHub"
        echo -e "${YELLOW}Authentification :${NC} gh auth login"
        return 1
    fi
    
    gh repo list --limit 20 --json name,description --jq '.[] | "\(.name): \(.description)"' 2>/dev/null
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
    
    cd "$project_dir" || return 1
    
    if [ -d ".flox" ]; then
        echo -e "${GREEN}✅ Environnement Flox existe déjà${NC}"
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

# Environment lifecycle operations with Flox + PM2
env_start() {
    local identifier=$1 # Can be env_name or custom_path
    local project_dir=""
    local env_name=""
    local pm2_config=""

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
    # Check for existing port and doppler in ecosystem.config.cjs
    if [ -f "$pm2_config" ]; then
        port=$(cat "$pm2_config" | grep -oP 'PORT: \K[0-9]+' | head -1)
        if grep -q "doppler run" "$pm2_config"; then
            doppler_prefix="doppler run -- "
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
    
    if pm2 list | grep -q "│ $env_name"; then
        echo -e "${YELLOW}⚠️  Projet déjà en cours d'exécution, nettoyage...${NC}"
        pm2 delete "$env_name" >/dev/null 2>&1
        # Kill any lingering processes on the port to avoid zombies
        fuser -k "$port/tcp" >/dev/null 2>&1 || true
    fi
    
    pm2 start "$pm2_config"
    pm2 save >/dev/null 2>&1
    success "Projet $env_name démarré sur le port $port"
}

env_stop() {
    local identifier=$1
    local project_dir=$(resolve_project_path "$identifier")
    
    if [ -z "$project_dir" ]; then
        warning "Projet $identifier introuvable ou chemin invalide."
        return 1
    fi

    # Ensure env_name is correctly derived for PM2 operations if a custom path was passed
    local pm2_app_name=$(basename "$project_dir") 

    if ! pm2 list | grep -q "│ $pm2_app_name"; then
        warning "Projet $pm2_app_name n'est pas en cours d'exécution"
        return 0
    fi
    
    pm2 stop "$pm2_app_name" >/dev/null 2>&1
    pm2 save >/dev/null 2>&1
    success "Projet $pm2_app_name arrêté"
}

env_remove() {
    local identifier=$1
    local project_dir=$(resolve_project_path "$identifier")
    
    if [ -z "$project_dir" ]; then
        warning "Projet $identifier introuvable ou chemin invalide. Impossible de supprimer."
        return 1
    fi

    local env_name=$(basename "$project_dir") # Use basename as the PM2 app name
    
    # Stop PM2 process if running
    if pm2 list | grep -q "│ $env_name"; then
        echo -e "${YELLOW}🛑 Arrêt du processus PM2 $env_name...${NC}"
        pm2 delete "$env_name" >/dev/null 2>&1
        pm2 save >/dev/null 2>&1
    fi
    
    # Remove project directory
    if [ -d "$project_dir" ]; then
        rm -rf "$project_dir"
        success "Projet $env_name supprimé"
    else
        warning "Répertoire $project_dir introuvable (peut-être déjà supprimé ou chemin incorrect)"
    fi
}


