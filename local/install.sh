#!/bin/bash
# install.sh - Installation automatique pour machine locale

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSH_CONFIG="$HOME/.ssh/config"
SHELL_RC="$HOME/.bashrc"

# Détecter le système d'exploitation
IS_WSL=false
IS_WINDOWS=false
IS_MACOS=false
IS_LINUX=false

if grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null; then
    IS_WSL=true
    IS_WINDOWS=true
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "win32" ]]; then
    IS_WINDOWS=true
elif [[ "$OSTYPE" == "darwin"* ]]; then
    IS_MACOS=true
else
    IS_LINUX=true
fi

# Détecter le shell (bash ou zsh)
if [ -n "$ZSH_VERSION" ]; then
    SHELL_RC="$HOME/.zshrc"
elif [ -f "$HOME/.zshrc" ] && [ -n "$SHELL" ] && [[ "$SHELL" == *"zsh"* ]]; then
    SHELL_RC="$HOME/.zshrc"
fi

echo -e "${BLUE}🚀 Installation BuildFlowz - Configuration Locale${NC}"
echo ""

# Afficher le système détecté
if [ "$IS_WSL" = true ]; then
    echo -e "${GREEN}✓ Système détecté: Windows WSL${NC}"
elif [ "$IS_WINDOWS" = true ]; then
    echo -e "${YELLOW}⚠ Système détecté: Windows (Git Bash)${NC}"
    echo -e "${YELLOW}  Pour une meilleure expérience, utilisez WSL (Windows Subsystem for Linux)${NC}"
    echo ""
elif [ "$IS_MACOS" = true ]; then
    echo -e "${GREEN}✓ Système détecté: macOS${NC}"
else
    echo -e "${GREEN}✓ Système détecté: Linux${NC}"
fi
echo ""

# 1. Vérifier autossh
echo -e "${BLUE}1. Vérification des dépendances...${NC}"
if ! command -v autossh &> /dev/null; then
    echo -e "${RED}   ✗ autossh non installé${NC}"
    echo -e "${YELLOW}   Installation requise:${NC}"

    if [ "$IS_MACOS" = true ]; then
        echo -e "${YELLOW}     brew install autossh${NC}"
    elif [ "$IS_WSL" = true ]; then
        echo -e "${YELLOW}     sudo apt update && sudo apt install autossh${NC}"
    elif [ "$IS_WINDOWS" = true ]; then
        echo -e "${RED}   ⚠️  Git Bash ne supporte pas autossh nativement${NC}"
        echo -e "${YELLOW}   Solutions recommandées:${NC}"
        echo -e "${YELLOW}   1. Installer WSL: https://aka.ms/wsl${NC}"
        echo -e "${YELLOW}   2. Utiliser PowerShell avec OpenSSH (voir install_local.ps1)${NC}"
        echo -e "${YELLOW}   3. Utiliser un client SSH graphique (PuTTY, MobaXterm)${NC}"
    else
        echo -e "${YELLOW}     sudo apt update && sudo apt install autossh${NC}"
    fi
    exit 1
fi
echo -e "${GREEN}   ✓ autossh installé${NC}"

# 2. Configurer SSH
echo ""
echo -e "${BLUE}2. Configuration SSH...${NC}"

# Créer ~/.ssh si nécessaire
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# Vérifier si la config existe déjà
if grep -q "Host hetzner" "$SSH_CONFIG" 2>/dev/null; then
    echo -e "${YELLOW}   ⚠ Configuration 'hetzner' existe déjà dans $SSH_CONFIG${NC}"
    echo -e "${YELLOW}   Vérifiez manuellement si l'IP est correcte (5.75.134.202)${NC}"
else
    # Ajouter la configuration SSH
    cat >> "$SSH_CONFIG" << 'EOF'

# BuildFlowz - Serveur Hetzner
Host hetzner
    HostName 5.75.134.202
    User root
    IdentityFile ~/.ssh/id_ed25519
    ServerAliveInterval 60
    ServerAliveCountMax 3
    TCPKeepAlive yes
    Compression yes
    ControlMaster auto
    ControlPath ~/.ssh/control-%r@%h:%p
    ControlPersist 10m
EOF
    chmod 600 "$SSH_CONFIG"
    echo -e "${GREEN}   ✓ Configuration SSH ajoutée${NC}"
fi

# 3. Ajouter les alias
echo ""
echo -e "${BLUE}3. Ajout des alias shell...${NC}"

ALIAS_BLOCK="
# BuildFlowz - Alias pour tunnels SSH
alias urls='$SCRIPT_DIR/local.sh'
alias tunnel='$SCRIPT_DIR/local.sh'
"

if grep -q "# BuildFlowz - Alias pour tunnels SSH" "$SHELL_RC" 2>/dev/null; then
    echo -e "${YELLOW}   ⚠ Alias déjà présents dans $SHELL_RC${NC}"
else
    echo "$ALIAS_BLOCK" >> "$SHELL_RC"
    echo -e "${GREEN}   ✓ Alias ajoutés à $SHELL_RC${NC}"
fi

# 4. Rendre les scripts exécutables
echo ""
echo -e "${BLUE}4. Configuration des permissions...${NC}"
chmod +x "$SCRIPT_DIR/dev-tunnel.sh"
chmod +x "$SCRIPT_DIR/local.sh"
echo -e "${GREEN}   ✓ Scripts exécutables${NC}"

# 5. Résumé
echo ""
echo -e "${GREEN}✅ Installation terminée !${NC}"
echo ""
echo -e "${BLUE}📋 Commandes disponibles:${NC}"
echo -e "   ${GREEN}urls${NC} ou ${GREEN}tunnel${NC}         - Ouvrir le menu de gestion des tunnels"
echo ""
echo -e "${YELLOW}⚠  Pour activer les alias, rechargez votre shell:${NC}"
echo -e "   ${BLUE}source $SHELL_RC${NC}"
echo -e "   ${YELLOW}ou${NC} fermez et rouvrez votre terminal"
echo ""
echo -e "${BLUE}🚀 Test de connexion SSH:${NC}"
if ssh -o ConnectTimeout=5 -o BatchMode=yes hetzner "echo OK" &>/dev/null; then
    echo -e "${GREEN}   ✓ Connexion SSH au serveur OK${NC}"
    echo ""
    echo -e "${GREEN}   Vous pouvez maintenant lancer: ${BLUE}urls${NC}"
else
    echo -e "${YELLOW}   ⚠ Impossible de se connecter au serveur${NC}"
    echo -e "${YELLOW}   Vérifiez que votre clé SSH est configurée:${NC}"
    echo -e "   ${BLUE}ssh-copy-id hetzner${NC}"
fi
