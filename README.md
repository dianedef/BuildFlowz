# BuildFlowz CLI

Menu interactif pour gérer vos environnements de développement avec Flox + PM2.

## 📁 Structure

```
BuildFlowz/
├── lib.sh                  # Bibliothèque partagée (fonctions réutilisables)
├── menu_simple_color.sh    # Menu interactif principal
├── local-setup/            # Configuration machine locale (tunnels SSH)
│   ├── menu_local.sh       # Menu gestion tunnels
│   ├── dev-tunnel.sh       # Script de création tunnels
│   └── install_local.sh    # Installation automatique
└── ECOSYSTEM-AND-PORTS.md  # Documentation gestion ports et ecosystem
```

## 🏗️ Architecture

### lib.sh
Contient toute la logique réutilisable :
- **Gestion intelligente des ports** (détection, allocation automatique anti-collision)
- **Création automatique ecosystem.config.cjs** pour PM2 avec variable PORT persistante
- Détection de type de projet (Node.js, Python, Rust, Go)
- Initialisation environnements Flox
- Fonctions de cycle de vie des environnements (start/stop/remove)
- Utilitaires GitHub CLI
- Configuration automatique des frameworks (Astro, Vite, Next.js, Nuxt)

### menu_simple_color.sh
Interface utilisateur en mode menu interactif :
- Navigation dans /root
- Lister les environnements
- Afficher les URLs
- Stopper un environnement
- Ouvrir le répertoire de code
- Déployer un repo GitHub
- Supprimer un environnement
- Démarrer un environnement

## 🚀 Utilisation

### Sur le serveur
```bash
cd /root/BuildFlowz
./menu_simple_color.sh
```

### Sur votre machine locale
```bash
# Installation (une fois)
cd ~/BuildFlowz/local-setup
./install_local.sh

# Utilisation
urls  # ou tunnel
# Choisir option 1 pour démarrer les tunnels SSH
```

## 🔌 Gestion automatique des ports

BuildFlowz gère automatiquement l'allocation des ports pour éviter les collisions :
- Détecte les ports actifs et ceux assignés dans PM2
- Assigne automatiquement le prochain port disponible (3000-3100)
- Crée un fichier `ecosystem.config.cjs` persistant avec variable `PORT`
- Compatible avec les tunnels SSH locaux (détection automatique)

**Pour plus de détails** : voir [ECOSYSTEM-AND-PORTS.md](./ECOSYSTEM-AND-PORTS.md)

## 📚 Documentation

- **[ECOSYSTEM-AND-PORTS.md](./ECOSYSTEM-AND-PORTS.md)** - Gestion ports et ecosystem PM2
- **[local-setup/README.md](./local-setup/README.md)** - Configuration tunnels SSH locaux

## 💡 Fonctionnalités clés

✅ Initialisation automatique environnements Flox  
✅ Détection framework et configuration automatique  
✅ Allocation intelligente des ports (anti-collision)  
✅ Fichiers ecosystem.config.cjs persistants  
✅ Support tunnels SSH pour accès local  
✅ Gestion cycle de vie PM2 (start/stop/remove)  
✅ Clone et déploiement repos GitHub  

## 🛠️ Technologies

- **Flox** - Environnements de développement isolés
- **PM2** - Gestionnaire de processus Node.js
- **SSH/autossh** - Tunnels pour accès local
- **Python/Bash** - Scripts d'automatisation
