# 🏠 Configuration Machine Locale

Scripts pour accéder aux applications du serveur Hetzner depuis votre machine locale via des tunnels SSH.

## 📋 Prérequis

### Installation des outils

**macOS :**
```bash
brew install autossh
```

**Linux (Debian/Ubuntu) :**
```bash
sudo apt install autossh
```

**Windows :**
Voir [README_WINDOWS.md](./README_WINDOWS.md) pour les 3 options disponibles:
- ✅ **WSL** (recommandé) - Support complet avec menu interactif
- ⚡ **PowerShell** - Simple avec OpenSSH natif
- 🔧 **Git Bash** - Environnement bash familier

## 🔧 Installation Automatique

### Installation rapide (recommandé)

**Linux / macOS / WSL:**
```bash
# Cloner le repo
git clone <votre-repo> ~/BuildFlowz
cd ~/BuildFlowz/local

# Lancer l'installation
./install.sh

# Recharger le shell
source ~/.bashrc  # ou source ~/.zshrc
```

**Windows (PowerShell):**
```powershell
# Cloner le repo
git clone <votre-repo> $env:USERPROFILE\BuildFlowz
cd $env:USERPROFILE\BuildFlowz\local

# Lancer l'installation
.\install_local.ps1

# Recharger le profil
. $PROFILE
```

Le script installe automatiquement :
- ✅ Configuration SSH (IP: 5.75.134.202)
- ✅ Alias shell : `urls`, `tunnel`
- ✅ Menu interactif pour gérer les tunnels (Linux/macOS/WSL)
- ✅ Script de tunnel pour Windows PowerShell
- ✅ Permissions exécutables

### Installation manuelle (optionnelle)

Si vous préférez configurer manuellement :

1. **Configuration SSH** - Copier `ssh-config` dans `~/.ssh/config`
2. **Alias** - Ajouter dans `~/.bashrc` ou `~/.zshrc` :
   ```bash
   alias urls='~/BuildFlowz/local/dev-tunnel.sh'
   ```

## 🚀 Utilisation

### Commandes disponibles

```bash
urls              # Ouvrir le menu de gestion des tunnels
tunnel            # Alias identique à urls
```

### Menu interactif

Le menu offre :
- 🚇 **Démarrer les tunnels** - Détecte automatiquement les projets PM2 actifs
- 📋 **Afficher les URLs** - Liste toutes les URLs localhost disponibles
- 🛑 **Arrêter les tunnels** - Arrête tous les tunnels en cours
- 📊 **Statut** - Vérifie l'état des tunnels actifs
- 🔄 **Redémarrer** - Redémarre tous les tunnels

### Workflow

```bash
# Sur votre machine locale
urls              # Ouvre le menu interactif
# Choisir option 1 pour démarrer les tunnels
```

Le système :
- ✅ Détecte automatiquement tous les projets PM2 actifs sur Hetzner
- ✅ Récupère leurs ports
- ✅ Crée des tunnels SSH pour chaque port
- ✅ Affiche les URLs accessibles (localhost:3000, etc.)
- ✅ Maintient les tunnels actifs en arrière-plan

### Accéder aux applications

Ouvrez votre navigateur :
- `http://localhost:3000` (projet sur port 3000)
- `http://localhost:3001` (projet sur port 3001)
- etc.

## 🔄 Workflow typique

1. **Sur votre machine locale :** `./dev-tunnel.sh`
2. **SSH sur Hetzner (avec mosh) :** `mosh hetzner`
3. **Démarrer les projets :** `dev-start`
4. **Dans votre navigateur :** Ouvrir `localhost:PORT`

## 🐛 Dépannage

### Le script ne trouve pas de ports

Vérifiez que PM2 tourne sur le serveur :
```bash
ssh hetzner "pm2 list"
```

### Les tunnels ne se créent pas

Vérifiez la configuration SSH :
```bash
ssh hetzner "echo Connection OK"
```

### Port déjà utilisé localement

Arrêtez le processus qui utilise le port ou modifiez la configuration PM2 sur le serveur.

## 📝 Notes

- Les tunnels restent actifs même si vous fermez le terminal
- `autossh` recrée automatiquement les tunnels en cas de déconnexion
- Les ports sont mappés 1:1 (port distant 3000 → port local 3000)
