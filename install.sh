#!/bin/bash

# Script d'installation des dépendances pour DevServer
# À exécuter une seule fois avant d'utiliser le menu

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}          ${YELLOW}DevServer Installation${NC}            ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# Fonction helper
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

# Vérifier si on est root
if [ "$EUID" -ne 0 ]; then 
    error "Ce script doit être exécuté en tant que root"
    echo -e "${YELLOW}Utilisez: sudo ./install.sh${NC}"
    exit 1
fi

echo -e "${BLUE}🔍 Vérification des dépendances...${NC}"
echo ""

# 1. Installer Node.js (pour PM2)
if command -v node >/dev/null 2>&1; then
    NODE_VERSION=$(node --version)
    success "Node.js déjà installé: $NODE_VERSION"
else
    info "Installation de Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
    apt-get install -y nodejs
    
    if command -v node >/dev/null 2>&1; then
        success "Node.js installé: $(node --version)"
    else
        error "Échec de l'installation de Node.js"
        exit 1
    fi
fi

echo ""

# 2. Installer PM2
if command -v pm2 >/dev/null 2>&1; then
    PM2_VERSION=$(pm2 --version)
    success "PM2 déjà installé: $PM2_VERSION"
else
    info "Installation de PM2..."
    npm install -g pm2
    
    if command -v pm2 >/dev/null 2>&1; then
        success "PM2 installé: $(pm2 --version)"
    else
        error "Échec de l'installation de PM2"
        exit 1
    fi
fi

echo ""

# 3. Configurer PM2 pour démarrer au boot
info "Configuration de PM2 pour démarrage automatique..."
pm2 startup systemd -u root --hp /root >/dev/null 2>&1
success "PM2 configuré pour démarrer automatiquement"

echo ""

# 4. Installer Flox
if command -v flox >/dev/null 2>&1; then
    FLOX_VERSION=$(flox --version 2>&1 | head -n1)
    success "Flox déjà installé: $FLOX_VERSION"
else
    info "Installation de Flox..."
    ARCH=$(uname -m)
    FLOX_VERSION="1.8.1"
    
    # Télécharger et installer le package Flox selon l'architecture
    cd /tmp
    if [ "$ARCH" = "aarch64" ]; then
        FLOX_DEB="flox-${FLOX_VERSION}.aarch64-linux.deb"
    else
        FLOX_DEB="flox-${FLOX_VERSION}.x86_64-linux.deb"
    fi
    
    curl -L -o "$FLOX_DEB" "https://downloads.flox.dev/by-env/stable/deb/$FLOX_DEB"
    dpkg -i "$FLOX_DEB"
    rm -f "$FLOX_DEB"
    
    if command -v flox >/dev/null 2>&1; then
        success "Flox installé: $(flox --version)"
    else
        error "Échec de l'installation de Flox"
        warning "Installation manuelle requise: https://flox.dev/docs/install-flox/"
    fi
fi

echo ""

# 5. Installer les outils système nécessaires
info "Vérification des outils système..."

TOOLS_TO_CHECK=("git" "curl" "python3" "ss")
MISSING_TOOLS=()

for tool in "${TOOLS_TO_CHECK[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        success "$tool installé"
    else
        MISSING_TOOLS+=("$tool")
    fi
done

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    info "Installation des outils manquants: ${MISSING_TOOLS[*]}"
    apt-get update >/dev/null 2>&1
    for tool in "${MISSING_TOOLS[@]}"; do
        case $tool in
            "ss")
                apt-get install -y iproute2
                ;;
            *)
                apt-get install -y "$tool"
                ;;
        esac
    done
    success "Outils système installés"
fi

echo ""

# 6. Vérifier/Installer GitHub CLI
if command -v gh >/dev/null 2>&1; then
    GH_VERSION=$(gh --version | head -n1)
    success "GitHub CLI déjà installé: $GH_VERSION"
else
    info "Installation de GitHub CLI..."
    type -p curl >/dev/null || apt install curl -y
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    apt update
    apt install gh -y
    
    if command -v gh >/dev/null 2>&1; then
        success "GitHub CLI installé: $(gh --version | head -n1)"
    else
        error "Échec de l'installation de GitHub CLI"
    fi
fi

echo ""

# 7. Installer PyYAML pour la gestion des fichiers compose
info "Installation de PyYAML..."
if python3 -c "import yaml" 2>/dev/null; then
    success "PyYAML déjà installé"
else
    apt-get install -y python3-pip >/dev/null 2>&1
    pip3 install pyyaml >/dev/null 2>&1
    success "PyYAML installé"
fi

echo ""

# 8. Installer Caddy (pour publication web)
if command -v caddy >/dev/null 2>&1; then
    CADDY_VERSION=$(caddy version | head -n1)
    success "Caddy déjà installé: $CADDY_VERSION"
else
    info "Installation de Caddy..."
    apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl >/dev/null 2>&1
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list > /dev/null
    apt-get update >/dev/null 2>&1
    apt-get install -y caddy >/dev/null 2>&1
    
    if command -v caddy >/dev/null 2>&1; then
        success "Caddy installé: $(caddy version | head -n1)"
    else
        error "Échec de l'installation de Caddy"
        warning "Installation manuelle requise: https://caddyserver.com/docs/install"
    fi
fi

echo ""

# 9. Créer le répertoire de configuration
DOKPLOY_DIR="/etc/dokploy/compose"
if [ ! -d "$DOKPLOY_DIR" ]; then
    info "Création du répertoire de configuration..."
    mkdir -p "$DOKPLOY_DIR"
    success "Répertoire créé: $DOKPLOY_DIR"
else
    success "Répertoire de configuration existe: $DOKPLOY_DIR"
fi

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${NC}          ${YELLOW}Installation terminée !${NC}              ${CYAN}║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${BLUE}📝 Prochaines étapes :${NC}"
echo ""
echo -e "1. ${YELLOW}Authentification GitHub${NC} (si pas déjà fait) :"
echo -e "   ${CYAN}gh auth login${NC}"
echo ""
echo -e "2. ${YELLOW}Lancer le menu DevServer${NC} :"
echo -e "   ${CYAN}cd /root/dokploy/cli${NC}"
echo -e "   ${CYAN}./menu_simple_color.sh${NC}"
echo ""

# Résumé des installations
echo -e "${BLUE}🎯 Résumé :${NC}"
echo -e "  • Node.js: $(command -v node >/dev/null 2>&1 && echo '✅' || echo '❌')"
echo -e "  • PM2: $(command -v pm2 >/dev/null 2>&1 && echo '✅' || echo '❌')"
echo -e "  • Flox: $(command -v flox >/dev/null 2>&1 && echo '✅' || echo '⚠️ Installation manuelle requise')"
echo -e "  • GitHub CLI: $(command -v gh >/dev/null 2>&1 && echo '✅' || echo '❌')"
echo -e "  • Caddy: $(command -v caddy >/dev/null 2>&1 && echo '✅' || echo '⚠️ Installation manuelle requise')"
echo -e "  • Python3: $(command -v python3 >/dev/null 2>&1 && echo '✅' || echo '❌')"
echo -e "  • PyYAML: $(python3 -c 'import yaml' 2>/dev/null && echo '✅' || echo '❌')"
echo -e "  • Git: $(command -v git >/dev/null 2>&1 && echo '✅' || echo '❌')"
echo ""

success "Vous pouvez maintenant utiliser le menu DevServer !"
