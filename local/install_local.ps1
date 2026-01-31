# install_local.ps1 - Installation automatique pour Windows (PowerShell)
# Requires: OpenSSH Client (installé par défaut sur Windows 10+)

$ErrorActionPreference = "Stop"

$GREEN = "`e[32m"
$BLUE = "`e[34m"
$YELLOW = "`e[33m"
$RED = "`e[31m"
$NC = "`e[0m"

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$SSH_CONFIG = "$env:USERPROFILE\.ssh\config"

Write-Host "${BLUE}🚀 Installation BuildFlowz - Configuration Windows${NC}"
Write-Host ""

# 1. Vérifier OpenSSH Client
Write-Host "${BLUE}1. Vérification des dépendances...${NC}"

$sshInstalled = Get-Command ssh -ErrorAction SilentlyContinue
if (-not $sshInstalled) {
    Write-Host "${RED}   ✗ OpenSSH Client non installé${NC}"
    Write-Host "${YELLOW}   Installation requise:${NC}"
    Write-Host "${YELLOW}   1. Ouvrir Paramètres Windows > Applications > Fonctionnalités facultatives${NC}"
    Write-Host "${YELLOW}   2. Ajouter 'Client OpenSSH'${NC}"
    Write-Host "${YELLOW}   Ou via PowerShell (admin):${NC}"
    Write-Host "${YELLOW}     Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0${NC}"
    exit 1
}
Write-Host "${GREEN}   ✓ OpenSSH Client installé${NC}"

# Vérifier si ssh-agent est actif
$sshAgentService = Get-Service -Name ssh-agent -ErrorAction SilentlyContinue
if ($sshAgentService -and $sshAgentService.Status -ne "Running") {
    Write-Host "${YELLOW}   ⚠ Activation du service ssh-agent...${NC}"
    Set-Service -Name ssh-agent -StartupType Automatic
    Start-Service ssh-agent
}

Write-Host ""

# 2. Configurer SSH
Write-Host "${BLUE}2. Configuration SSH...${NC}"

# Créer le répertoire .ssh si nécessaire
$sshDir = "$env:USERPROFILE\.ssh"
if (-not (Test-Path $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir | Out-Null
}

# Vérifier si la config existe déjà
if ((Test-Path $SSH_CONFIG) -and (Select-String -Path $SSH_CONFIG -Pattern "Host hetzner" -Quiet)) {
    Write-Host "${YELLOW}   ⚠ Configuration 'hetzner' existe déjà dans $SSH_CONFIG${NC}"
    Write-Host "${YELLOW}   Vérifiez manuellement si l'IP est correcte (5.75.134.202)${NC}"
} else {
    # Ajouter la configuration SSH
    $sshConfigContent = @"

# BuildFlowz - Serveur Hetzner
Host hetzner
    HostName 5.75.134.202
    User root
    IdentityFile ~/.ssh/id_ed25519
    ServerAliveInterval 60
    ServerAliveCountMax 3
    TCPKeepAlive yes
    Compression yes
"@

    Add-Content -Path $SSH_CONFIG -Value $sshConfigContent
    Write-Host "${GREEN}   ✓ Configuration SSH ajoutée${NC}"
}

Write-Host ""

# 3. Créer un script de tunnel
Write-Host "${BLUE}3. Création du script de tunnel...${NC}"

$tunnelScriptPath = "$SCRIPT_DIR\start-tunnel.ps1"
$tunnelScriptContent = @"
# start-tunnel.ps1 - Démarrer un tunnel SSH
# Usage: .\start-tunnel.ps1 -Port 3001

param(
    [Parameter(Mandatory=`$true)]
    [int]`$Port
)

Write-Host "🔗 Démarrage du tunnel SSH pour le port `$Port..."
Write-Host "URL locale: http://localhost:`$Port"
Write-Host ""
Write-Host "Appuyez sur Ctrl+C pour arrêter le tunnel"
Write-Host ""

ssh -N -L ${Port}:localhost:${Port} hetzner
"@

Set-Content -Path $tunnelScriptPath -Value $tunnelScriptContent
Write-Host "${GREEN}   ✓ Script de tunnel créé: start-tunnel.ps1${NC}"

Write-Host ""

# 4. Ajouter au PATH (optionnel)
Write-Host "${BLUE}4. Configuration des raccourcis...${NC}"

$profilePath = $PROFILE
if (-not (Test-Path $profilePath)) {
    New-Item -ItemType File -Path $profilePath -Force | Out-Null
}

$aliasBlock = @"

# BuildFlowz - Alias pour tunnels SSH
function tunnel { param([int]`$Port) & "$tunnelScriptPath" -Port `$Port }
"@

if (-not (Select-String -Path $profilePath -Pattern "BuildFlowz - Alias" -Quiet)) {
    Add-Content -Path $profilePath -Value $aliasBlock
    Write-Host "${GREEN}   ✓ Alias ajouté au profil PowerShell${NC}"
} else {
    Write-Host "${YELLOW}   ⚠ Alias déjà présent dans le profil PowerShell${NC}"
}

Write-Host ""

# 5. Résumé
Write-Host "${GREEN}✅ Installation terminée !${NC}"
Write-Host ""
Write-Host "${BLUE}📋 Utilisation:${NC}"
Write-Host ""
Write-Host "   ${YELLOW}Méthode 1: Via script direct${NC}"
Write-Host "   ${GREEN}.\start-tunnel.ps1 -Port 3001${NC}"
Write-Host ""
Write-Host "   ${YELLOW}Méthode 2: Via alias (après redémarrage PowerShell)${NC}"
Write-Host "   ${GREEN}tunnel 3001${NC}"
Write-Host ""
Write-Host "   ${YELLOW}Méthode 3: Tunnel SSH manuel${NC}"
Write-Host "   ${GREEN}ssh -N -L 3001:localhost:3001 hetzner${NC}"
Write-Host ""
Write-Host "${YELLOW}⚠  Pour activer les alias, rechargez votre profil PowerShell:${NC}"
Write-Host "   ${BLUE}. `$PROFILE${NC}"
Write-Host "   ${YELLOW}ou${NC} fermez et rouvrez PowerShell"
Write-Host ""

# 6. Test de connexion SSH
Write-Host "${BLUE}🚀 Test de connexion SSH:${NC}"
try {
    $sshTest = ssh -o ConnectTimeout=5 -o BatchMode=yes hetzner "echo OK" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "${GREEN}   ✓ Connexion SSH au serveur OK${NC}"
        Write-Host ""
        Write-Host "${GREEN}   Vous pouvez maintenant utiliser: ${BLUE}tunnel 3001${NC}"
    } else {
        throw "SSH connection failed"
    }
} catch {
    Write-Host "${YELLOW}   ⚠ Impossible de se connecter au serveur${NC}"
    Write-Host "${YELLOW}   Vérifiez que votre clé SSH est configurée:${NC}"
    Write-Host ""
    Write-Host "   ${BLUE}1. Générer une clé SSH (si pas déjà fait):${NC}"
    Write-Host "      ${GREEN}ssh-keygen -t ed25519 -C 'your_email@example.com'${NC}"
    Write-Host ""
    Write-Host "   ${BLUE}2. Copier la clé publique:${NC}"
    Write-Host "      ${GREEN}Get-Content `$env:USERPROFILE\.ssh\id_ed25519.pub | clip${NC}"
    Write-Host "      ${YELLOW}(La clé est maintenant dans le presse-papiers)${NC}"
    Write-Host ""
    Write-Host "   ${BLUE}3. Ajouter la clé sur le serveur:${NC}"
    Write-Host "      ${GREEN}ssh root@5.75.134.202${NC}"
    Write-Host "      ${YELLOW}Collez votre clé publique dans ~/.ssh/authorized_keys${NC}"
}

Write-Host ""
Write-Host "${BLUE}💡 Astuce: Pour WSL (meilleure intégration), utilisez:${NC}"
Write-Host "   ${GREEN}wsl --install${NC}"
Write-Host "   ${YELLOW}Puis exécutez ./install_local.sh dans WSL${NC}"
