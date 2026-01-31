#!/bin/bash

# Menu Local - Gestion des tunnels SSH vers Hetzner
# Accès rapide aux projets distants via tunnels SSH

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Configuration file for saved connections
CONFIG_DIR="$HOME/.buildflowz"
CONNECTIONS_FILE="$CONFIG_DIR/connections.conf"
CURRENT_CONNECTION_FILE="$CONFIG_DIR/current_connection"

# Initialize config directory
mkdir -p "$CONFIG_DIR" 2>/dev/null

# Load or set default connection
load_current_connection() {
    if [ -f "$CURRENT_CONNECTION_FILE" ]; then
        REMOTE_HOST=$(cat "$CURRENT_CONNECTION_FILE")
    else
        REMOTE_HOST="hetzner"
    fi
}

# Save current connection
save_current_connection() {
    echo "$REMOTE_HOST" > "$CURRENT_CONNECTION_FILE"
}

# Add connection to saved list
add_saved_connection() {
    local connection="$1"
    # Create file if not exists
    touch "$CONNECTIONS_FILE"
    # Add if not already present
    if ! grep -q "^${connection}$" "$CONNECTIONS_FILE" 2>/dev/null; then
        echo "$connection" >> "$CONNECTIONS_FILE"
    fi
}

# Get saved connections
get_saved_connections() {
    if [ -f "$CONNECTIONS_FILE" ]; then
        cat "$CONNECTIONS_FILE" | sort -u
    fi
}

# Menu to select/add connection
select_connection() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}          ${YELLOW}🔌 Gestion des connexions${NC}            ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Connexion actuelle:${NC} ${GREEN}$REMOTE_HOST${NC}"
    echo ""

    # Get saved connections
    local saved=$(get_saved_connections)
    local options=()
    local i=1

    echo -e "${BLUE}Connexions enregistrées:${NC}"
    echo ""

    if [ -n "$saved" ]; then
        while IFS= read -r conn; do
            if [ "$conn" = "$REMOTE_HOST" ]; then
                echo -e "  ${CYAN}$i)${NC} $conn ${GREEN}(actuel)${NC}"
            else
                echo -e "  ${CYAN}$i)${NC} $conn"
            fi
            options+=("$conn")
            ((i++))
        done <<< "$saved"
    else
        echo -e "  ${YELLOW}Aucune connexion enregistrée${NC}"
    fi

    echo ""
    echo -e "  ${CYAN}n)${NC} ➕ Nouvelle connexion"
    echo -e "  ${CYAN}0)${NC} ← Retour"
    echo ""
    echo -e "${YELLOW}Votre choix:${NC} \c"
    read -r choice

    case "$choice" in
        0)
            return 0
            ;;
        n|N)
            echo ""
            echo -e "${BLUE}Format: user@host ou alias SSH${NC}"
            echo -e "${YELLOW}Exemple: claude@hetzner, root@192.168.1.10, myserver${NC}"
            echo ""
            echo -e "${YELLOW}Nouvelle connexion:${NC} \c"
            read -r new_conn

            if [ -n "$new_conn" ]; then
                # Test connection
                echo ""
                echo -e "${BLUE}🔍 Test de connexion...${NC}"
                if ssh -o ConnectTimeout=5 -o BatchMode=yes "$new_conn" "echo ok" &>/dev/null; then
                    echo -e "${GREEN}✓ Connexion réussie!${NC}"
                    REMOTE_HOST="$new_conn"
                    save_current_connection
                    add_saved_connection "$new_conn"
                    # Invalidate session cache
                    CACHED_SESSION_INFO=""
                    CACHED_SESSION_TIME=0
                else
                    echo -e "${RED}✗ Échec de connexion à $new_conn${NC}"
                    echo -e "${YELLOW}Vérifiez l'adresse et votre configuration SSH${NC}"
                    pause
                fi
            fi
            ;;
        [1-9]|[1-9][0-9])
            local idx=$((choice - 1))
            if [ $idx -lt ${#options[@]} ]; then
                local selected="${options[$idx]}"
                echo ""
                echo -e "${BLUE}🔍 Test de connexion à $selected...${NC}"
                if ssh -o ConnectTimeout=5 -o BatchMode=yes "$selected" "echo ok" &>/dev/null; then
                    echo -e "${GREEN}✓ Connexion réussie!${NC}"
                    REMOTE_HOST="$selected"
                    save_current_connection
                    # Invalidate session cache
                    CACHED_SESSION_INFO=""
                    CACHED_SESSION_TIME=0
                else
                    echo -e "${RED}✗ Échec de connexion${NC}"
                    pause
                fi
            else
                echo -e "${RED}❌ Choix invalide${NC}"
                pause
            fi
            ;;
        *)
            echo -e "${RED}❌ Choix invalide${NC}"
            pause
            ;;
    esac
}

# Load connection at startup
load_current_connection

# Cached session info (to avoid repeated SSH calls)
CACHED_SESSION_INFO=""
CACHED_SESSION_TIME=0

# Function to retrieve server session info (with caching)
get_server_session_info() {
    local current_time=$(date +%s)
    local cache_ttl=300  # Cache for 5 minutes

    # Return cached info if fresh
    if [ -n "$CACHED_SESSION_INFO" ] && [ $((current_time - CACHED_SESSION_TIME)) -lt $cache_ttl ]; then
        echo "$CACHED_SESSION_INFO"
        return 0
    fi

    # Retrieve session info from server
    CACHED_SESSION_INFO=$(ssh -o ConnectTimeout=5 "$REMOTE_HOST" "
        if [ -f ~/BuildFlowz/lib.sh ]; then
            source ~/BuildFlowz/lib.sh 2>/dev/null
            get_session_info_for_ssh 2>/dev/null
        elif [ -f ~/.buildflowz/lib.sh ]; then
            source ~/.buildflowz/lib.sh 2>/dev/null
            get_session_info_for_ssh 2>/dev/null
        else
            echo 'SESSION_NOT_FOUND'
        fi
    " 2>/dev/null)

    CACHED_SESSION_TIME=$current_time
    echo "$CACHED_SESSION_INFO"
}

# Function to display server session banner
display_server_session_banner() {
    local session_info=$(get_server_session_info)

    if echo "$session_info" | grep -q "SESSION_START"; then
        # Parse session info
        local session_user=$(echo "$session_info" | grep "^USER:" | cut -d: -f2)
        local session_host=$(echo "$session_info" | grep "^HOST:" | cut -d: -f2)
        local session_code=$(echo "$session_info" | grep "^CODE:" | cut -d: -f2)
        local hash_art=$(echo "$session_info" | sed -n '/---HASH_ART_START---/,/---HASH_ART_END---/p' | grep -v "^---")

        echo -e "${CYAN}──────────────────────────────────────────────────${NC}"
        echo -e "${MAGENTA}  Server Session Identity${NC}"
        echo -e "${CYAN}──────────────────────────────────────────────────${NC}"
        echo ""

        # Display hash art
        while IFS= read -r line; do
            echo -e "              ${BLUE}$line${NC}"
        done <<< "$hash_art"

        echo ""
        echo -e "  ${GREEN}$session_user@$session_host${NC}    ${YELLOW}$session_code${NC}"
        echo -e "${CYAN}──────────────────────────────────────────────────${NC}"
    elif echo "$session_info" | grep -q "SESSION_NOT_FOUND"; then
        echo -e "${YELLOW}⚠ Session identity unavailable (BuildFlowz not found on server)${NC}"
    elif [ -z "$session_info" ]; then
        echo -e "${YELLOW}⚠ Could not connect to server${NC}"
    fi
}

# Fonction d'affichage avec couleurs
print_header() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}              ${YELLOW}BuildFlowz - Local${NC}              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}           ${BLUE}SSH Tunnel Manager${NC}              ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""

    # Display server session identity (includes user@host info)
    display_server_session_banner
    echo ""
}

# Fonction d'affichage du menu
show_menu() {
    echo -e "${GREEN}Choisissez une option :${NC}"
    echo ""
    echo -e "  ${CYAN}1)${NC} 🚇 Démarrer les tunnels SSH"
    echo -e "  ${CYAN}2)${NC} 📋 Afficher les URLs disponibles"
    echo -e "  ${CYAN}3)${NC} 🛑 Arrêter les tunnels"
    echo -e "  ${CYAN}4)${NC} 📊 Statut des tunnels"
    echo -e "  ${CYAN}5)${NC} 🔄 Redémarrer les tunnels"
    echo ""
    echo -e "  ${CYAN}7)${NC} 🔌 Changer de connexion"
    echo -e "  ${CYAN}0)${NC} ❌ Quitter"
    echo ""
}

# Fonction pour obtenir les ports actifs
get_active_ports() {
    ssh "$REMOTE_HOST" "pm2 jlist 2>/dev/null | python3 -c \"
import sys, json
try:
    apps = json.load(sys.stdin)
    for app in apps:
        if app['pm2_env']['status'] == 'online':
            env = app['pm2_env'].get('env', {})
            port = env.get('PORT') or env.get('port')
            if port:
                name = app['name']
                print(f'{port}:{name}')
except:
    pass
\"" 2>/dev/null
}

# Fonction pour démarrer les tunnels
start_tunnels() {
    echo -e "${BLUE}🚇 Démarrage des tunnels SSH${NC}"
    echo ""
    
    # Vérifier autossh
    if ! command -v autossh &> /dev/null; then
        echo -e "${RED}✗ autossh n'est pas installé${NC}"
        echo -e "${YELLOW}  Installation: brew install autossh (macOS) ou apt install autossh (Linux)${NC}"
        return 1
    fi
    
    # Arrêter les tunnels existants
    echo -e "${YELLOW}🛑 Arrêt des tunnels existants...${NC}"
    pkill -f "autossh.*$REMOTE_HOST" 2>/dev/null || true
    sleep 1
    
    # Récupérer les ports
    echo -e "${BLUE}📡 Récupération des ports actifs depuis PM2...${NC}"
    PORTS=$(get_active_ports)
    
    if [ -z "$PORTS" ]; then
        echo -e "${RED}✗ Aucun port trouvé ou PM2 n'est pas accessible${NC}"
        echo -e "${YELLOW}  Vérifiez que PM2 tourne sur le serveur distant${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ Création des tunnels SSH${NC}"
    echo ""
    
    # Créer les tunnels
    while IFS= read -r line; do
        port=$(echo "$line" | cut -d':' -f1)
        name=$(echo "$line" | cut -d':' -f2)
        
        echo -e "${GREEN}  ✓ localhost:${port} → ${name}${NC}"
        
        autossh -M 0 -f -N \
            -o "ServerAliveInterval=30" \
            -o "ServerAliveCountMax=3" \
            -o "ExitOnForwardFailure=yes" \
            -L "${port}:localhost:${port}" \
            "$REMOTE_HOST" 2>/dev/null
    done <<< "$PORTS"
    
    echo ""
    echo -e "${YELLOW}⏳ Attente de l'établissement des tunnels...${NC}"
    sleep 3
    
    echo -e "${GREEN}✅ Tunnels actifs !${NC}"
}

# Fonction pour afficher les URLs
show_urls() {
    echo -e "${BLUE}📋 URLs disponibles${NC}"
    echo ""
    
    PORTS=$(get_active_ports)
    
    if [ -z "$PORTS" ]; then
        echo -e "${RED}✗ Aucun port trouvé${NC}"
        return 1
    fi
    
    while IFS= read -r line; do
        port=$(echo "$line" | cut -d':' -f1)
        name=$(echo "$line" | cut -d':' -f2)
        
        # Vérifier si le port local est accessible (méthode la plus fiable)
        if command -v nc &> /dev/null && nc -z localhost "$port" 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} http://localhost:${port} ${YELLOW}(${name})${NC} ${GREEN}[actif]${NC}"
        elif command -v lsof &> /dev/null && lsof -i :${port} &> /dev/null; then
            echo -e "  ${GREEN}✓${NC} http://localhost:${port} ${YELLOW}(${name})${NC} ${GREEN}[actif]${NC}"
        elif curl -s --connect-timeout 1 http://localhost:${port} &> /dev/null; then
            echo -e "  ${GREEN}✓${NC} http://localhost:${port} ${YELLOW}(${name})${NC} ${GREEN}[actif]${NC}"
        else
            echo -e "  ${RED}✗${NC} http://localhost:${port} ${YELLOW}(${name})${NC} ${RED}[tunnel inactif]${NC}"
        fi
    done <<< "$PORTS"
}

# Fonction pour arrêter les tunnels
stop_tunnels() {
    echo -e "${BLUE}🛑 Arrêt des tunnels SSH${NC}"
    echo ""
    
    # Afficher les processus avant de les tuer
    echo -e "${YELLOW}🔍 Recherche des processus SSH...${NC}"
    
    PIDS=$(pgrep -f "ssh.*$REMOTE_HOST" 2>/dev/null)
    
    if [ -z "$PIDS" ]; then
        echo -e "${YELLOW}⚠ Aucun processus SSH trouvé avec le pattern 'ssh.*$REMOTE_HOST'${NC}"
        echo ""
        echo -e "${BLUE}💡 Processus SSH en cours:${NC}"
        ps aux | grep ssh | grep -v grep | grep -v ssh-agent
    else
        echo -e "${GREEN}✓ Processus trouvés:${NC}"
        echo "$PIDS" | while read -r pid; do
            cmd=$(ps -p "$pid" -o command= 2>/dev/null)
            echo -e "  ${CYAN}PID $pid:${NC} $cmd"
        done
        
        echo ""
        echo -e "${YELLOW}🔫 Arrêt des processus...${NC}"
        
        # Tuer les processus
        echo "$PIDS" | while read -r pid; do
            if kill "$pid" 2>/dev/null; then
                echo -e "  ${GREEN}✓${NC} PID $pid arrêté"
            else
                echo -e "  ${RED}✗${NC} Impossible d'arrêter PID $pid"
            fi
        done
        
        # Attendre un peu
        sleep 1
        
        # Vérifier qu'ils sont bien arrêtés
        REMAINING=$(pgrep -f "ssh.*$REMOTE_HOST" 2>/dev/null)
        if [ -n "$REMAINING" ]; then
            echo ""
            echo -e "${YELLOW}⚠ Processus restants, utilisation de kill -9...${NC}"
            echo "$REMAINING" | xargs kill -9 2>/dev/null
        fi
        
        echo ""
        echo -e "${GREEN}✓ Tunnels arrêtés${NC}"
    fi
}

# Fonction pour afficher le statut
show_status() {
    echo -e "${BLUE}📊 Statut des tunnels${NC}"
    echo ""
    
    # Chercher les processus autossh OU ssh avec le remote host
    PROCESSES=$(ps aux | grep -E "(autossh|ssh).*$REMOTE_HOST" | grep -v grep | grep -v "ssh-agent")
    
    if [ -z "$PROCESSES" ]; then
        echo -e "${YELLOW}⚠ Aucun tunnel actif${NC}"
        echo ""
        echo -e "${BLUE}💡 Vérification des ports en écoute:${NC}"
        if command -v lsof &> /dev/null; then
            lsof -iTCP -sTCP:LISTEN | grep "^ssh" | head -5 || echo "  Aucun port SSH trouvé"
        elif command -v netstat &> /dev/null; then
            netstat -an | grep LISTEN | grep "127.0.0.1:" | head -5 || echo "  Aucun port localhost trouvé"
        fi
    else
        echo -e "${GREEN}✓ Processus de tunnels actifs :${NC}"
        echo ""
        
        # Compter les processus
        COUNT=$(echo "$PROCESSES" | wc -l | tr -d ' ')
        echo -e "  ${GREEN}•${NC} $COUNT processus SSH/autossh vers $REMOTE_HOST"
        echo ""
        
        # Essayer d'extraire les ports
        echo -e "${BLUE}💡 Ports locaux en écoute (tunnels):${NC}"
        if command -v lsof &> /dev/null; then
            lsof -iTCP -sTCP:LISTEN -P | grep "^ssh" | awk '{print $9}' | grep -o "localhost:[0-9]*" | sort -u | while read -r addr; do
                port=$(echo "$addr" | cut -d: -f2)
                echo -e "  ${GREEN}•${NC} http://localhost:${port}"
            done
        else
            echo "$PROCESSES" | while read -r line; do
                port=$(echo "$line" | grep -oP '(?<=-L )\d+(?=:localhost)' | head -1)
                if [ -n "$port" ]; then
                    echo -e "  ${GREEN}•${NC} http://localhost:${port}"
                fi
            done
        fi
    fi
}

# Fonction de pause
pause() {
    echo ""
    echo -e "${YELLOW}Appuyez sur Entrée pour continuer...${NC}"
    read -r
}

# Fonction principale
main() {
    while true; do
        clear
        print_header
        show_menu

        echo -e "${YELLOW}Votre choix :${NC} \c"
        read -r CHOICE

        case $CHOICE in
            1)
                start_tunnels
                pause
                ;;
            2)
                show_urls
                pause
                ;;
            3)
                stop_tunnels
                pause
                ;;
            4)
                show_status
                pause
                ;;
            5)
                echo -e "${BLUE}🔄 Redémarrage des tunnels${NC}"
                echo ""
                stop_tunnels
                sleep 2
                start_tunnels
                pause
                ;;
            7)
                select_connection
                ;;
            0|6)
                echo -e "${GREEN}👋 Au revoir !${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Choix invalide${NC}"
                pause
                ;;
        esac
    done
}

# Lancer le menu
main
