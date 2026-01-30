#!/bin/bash
# dev-tunnel.sh - Crée des tunnels SSH automatiques pour tous les ports PM2 actifs

set -e

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../config.sh" ]; then
    source "$SCRIPT_DIR/../config.sh"
fi

REMOTE_USER="${REMOTE_USER:-$BUILDFLOWZ_SSH_REMOTE_USER}"
REMOTE_HOST="${REMOTE_HOST:-$BUILDFLOWZ_SSH_REMOTE_HOST}"
SSH_CONFIG="$HOME/.ssh/config"

# Validate remote host name
if [[ ! "$REMOTE_HOST" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    echo -e "${RED}✗ Invalid REMOTE_HOST: $REMOTE_HOST${NC}"
    echo -e "${YELLOW}  Host name can only contain letters, numbers, dash, underscore, dot${NC}"
    exit 1
fi

# Validate remote user name
if [[ ! "$REMOTE_USER" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    echo -e "${RED}✗ Invalid REMOTE_USER: $REMOTE_USER${NC}"
    echo -e "${YELLOW}  User name can only contain letters, numbers, dash, underscore, dot${NC}"
    exit 1
fi

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚇 Dev Tunnel Manager${NC}"
echo ""

# Retrieve and display server session identity
echo -e "${BLUE}🔐 Retrieving server session identity...${NC}"
SESSION_INFO=$(ssh "$REMOTE_HOST" "
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

if echo "$SESSION_INFO" | grep -q "SESSION_START"; then
    # Parse session info
    SESSION_USER=$(echo "$SESSION_INFO" | grep "^USER:" | cut -d: -f2)
    SESSION_HOST=$(echo "$SESSION_INFO" | grep "^HOST:" | cut -d: -f2)
    SESSION_CODE=$(echo "$SESSION_INFO" | grep "^CODE:" | cut -d: -f2)
    HASH_ART=$(echo "$SESSION_INFO" | sed -n '/---HASH_ART_START---/,/---HASH_ART_END---/p' | grep -v "^---")

    echo -e "${CYAN}┌──────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}        ${YELLOW}🔗 Connected Server Session${NC}              ${CYAN}│${NC}"
    echo -e "${CYAN}├──────────────────────────────────────────────────┤${NC}"

    # Display hash art with padding
    while IFS= read -r line; do
        printf "${CYAN}│${NC}               %s               ${CYAN}│${NC}\n" "$line"
    done <<< "$HASH_ART"

    echo -e "${CYAN}├──────────────────────────────────────────────────┤${NC}"
    printf "${CYAN}│${NC}    ${GREEN}%-15s${NC}   ${YELLOW}%-20s${NC}   ${CYAN}│${NC}\n" "$SESSION_USER@$SESSION_HOST" "$SESSION_CODE"
    echo -e "${CYAN}└──────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "${GREEN}✓ Verify this pattern matches the server menu${NC}"
    echo ""
elif echo "$SESSION_INFO" | grep -q "SESSION_DISABLED"; then
    echo -e "${YELLOW}⚠ Session identity is disabled on the server${NC}"
    echo ""
elif echo "$SESSION_INFO" | grep -q "SESSION_NOT_FOUND"; then
    echo -e "${YELLOW}⚠ BuildFlowz not found on server (session identity unavailable)${NC}"
    echo ""
else
    echo -e "${YELLOW}⚠ Could not retrieve session identity${NC}"
    echo ""
fi

# Vérifier que autossh est installé
if ! command -v autossh &> /dev/null; then
    echo -e "${RED}✗ autossh n'est pas installé${NC}"
    echo -e "${YELLOW}  Installation: brew install autossh (macOS) ou apt install autossh (Linux)${NC}"
    exit 1
fi

# Vérifier la configuration SSH
if ! grep -q "Host $REMOTE_HOST" "$SSH_CONFIG" 2>/dev/null; then
    echo -e "${YELLOW}⚠ Configuration SSH manquante pour '$REMOTE_HOST'${NC}"
    echo -e "${YELLOW}  Ajoutez la configuration dans $SSH_CONFIG (voir ssh-config)${NC}"
    exit 1
fi

# Récupérer les ports actifs depuis PM2 sur le serveur distant
echo -e "${BLUE}📡 Récupération des ports actifs depuis PM2...${NC}"

PORTS=$(ssh "$REMOTE_HOST" "pm2 jlist 2>/dev/null | python3 -c \"
import sys, json
try:
    apps = json.load(sys.stdin)
    ports = []
    for app in apps:
        if app['pm2_env']['status'] == 'online':
            env = app['pm2_env'].get('env', {})
            port = env.get('PORT') or env.get('port')
            if port:
                name = app['name']
                ports.append(f'{port}:{name}')
    print(','.join(ports))
except:
    pass
\"" 2>/dev/null)

if [ -z "$PORTS" ]; then
    echo -e "${RED}✗ Aucun port trouvé ou PM2 n'est pas accessible${NC}"
    echo -e "${YELLOW}  Vérifiez que PM2 tourne sur le serveur distant${NC}"
    exit 1
fi

# Arrêter les tunnels existants
echo -e "${BLUE}🛑 Arrêt des tunnels existants...${NC}"
pkill -f "autossh.*$REMOTE_HOST" 2>/dev/null || true
sleep 1

# Créer les tunnels
echo -e "${GREEN}✓ Création des tunnels SSH${NC}"
echo ""

IFS=',' read -ra PORT_ARRAY <<< "$PORTS"
for port_info in "${PORT_ARRAY[@]}"; do
    IFS=':' read -r port name <<< "$port_info"
    
    echo -e "${GREEN}  ✓ localhost:${port} → ${name}${NC}"
    
    # Créer le tunnel avec autossh (maintient la connexion)
    autossh -M 0 -f -N \
        -o "ServerAliveInterval=${BUILDFLOWZ_SSH_KEEPALIVE_INTERVAL:-30}" \
        -o "ServerAliveCountMax=${BUILDFLOWZ_SSH_KEEPALIVE_MAX:-3}" \
        -o "ExitOnForwardFailure=yes" \
        -L "${port}:localhost:${port}" \
        "$REMOTE_HOST" 2>/dev/null
done

echo ""
echo -e "${GREEN}✓ Tunnels actifs !${NC}"
echo ""
echo -e "${BLUE}📋 URLs disponibles :${NC}"

for port_info in "${PORT_ARRAY[@]}"; do
    IFS=':' read -r port name <<< "$port_info"
    echo -e "  • http://localhost:${port} ${YELLOW}(${name})${NC}"
done

echo ""
echo -e "${YELLOW}💡 Les tunnels restent actifs en arrière-plan${NC}"
echo -e "${YELLOW}   Pour les arrêter : pkill -f 'autossh.*$REMOTE_HOST'${NC}"
