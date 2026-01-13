# Migration vers Architecture Flox + PM2

## ✅ Changements effectués

### 1. Configuration globale
- **AVANT**: `DOKPLOY_DIR="/etc/dokploy/compose"`
- **APRÈS**: `PROJECTS_DIR="/root"`

### 2. Structure des projets
- **AVANT**: `/etc/dokploy/compose/projet/code/` + docker-compose.yml
- **APRÈS**: `/root/projet/` avec environnement Flox (.flox/)

### 3. Fonctions modifiées dans `lib.sh`

#### Nouvelles fonctions
- `detect_project_type()` - Détecte Node.js/Python/Rust/Go
- `init_flox_env()` - Crée/initialise environnement Flox
- `detect_dev_command()` - Détecte la commande de dev (npm/pnpm/yarn)
- `get_project_dir()` - Retourne le chemin du projet
- `get_port_from_pm2()` - Récupère le port depuis PM2

#### Fonctions remplacées
- ❌ `create_compose_for_project()` → ✅ `init_flox_env()`
- ❌ `get_config_file()` → ✅ `get_project_dir()`
- ❌ `get_ports_from_config()` → ✅ `get_port_from_pm2()`
- ❌ `reassign_ports_if_busy()` → Supprimée (gestion directe)

#### Fonctions mises à jour
- `list_all_environments()` - Cherche `.flox/` dans `/root`
- `cleanup_orphan_projects()` - Cherche projets sans Flox
- `env_start()` - Utilise `flox activate` + PM2
- `env_stop()` - PM2 stop
- `env_remove()` - PM2 delete + rm projet

### 4. Commandes du menu mises à jour

#### Commande 2 : Lister les environnements
- Affiche les projets avec environnement Flox
- Montre le statut PM2, chemin projet, et port

#### Commande 3 : Afficher les URLs
- Récupère le port depuis PM2
- Affiche localhost et IP publique

#### Commande 4 : Stopper un environnement
- Utilise `env_stop()` avec PM2

#### Commande 5 : Ouvrir le répertoire
- Ouvre directement `/root/projet`

#### Commande 6 : Déployer un repo GitHub
- Clone dans `/root/nom-du-repo`
- Initialise environnement Flox automatiquement
- Démarre avec PM2

#### Commande 7 : Supprimer un environnement
- Supprime via `env_remove()` (PM2 + dossier)

#### Commande 8 : Démarrer un environnement
- Utilise `env_start()` avec Flox + PM2

## 🚀 Comment tester

### Test 1 : Lister les environnements
```bash
cd /root/dokploy/cli
./menu_simple_color.sh
# Choisir option 2
```

### Test 2 : Démarrer un projet existant
```bash
# Le projet test-project existe déjà dans /root
./menu_simple_color.sh
# Choisir option 8, sélectionner test-project
```

### Test 3 : Déployer un repo GitHub
```bash
./menu_simple_color.sh
# Choisir option 6
# Sélectionner un repo
```

## 📝 Points importants

1. **Environnement Flox auto-créé** : Si un projet n'a pas de `.flox/`, il est créé automatiquement
2. **Ports dynamiques** : Assignés au démarrage, stockés dans PM2
3. **Plus de Docker** : Tout fonctionne avec Flox + PM2
4. **Projets dans `/root`** : Plus simple et direct
5. **Compatibilité** : Détection auto de npm/pnpm/yarn/Python/Rust/Go

## ⚠️ Migration des projets existants

Pour migrer un projet Docker existant :
1. Copier le code dans `/root/nom-projet/`
2. Lancer la commande 8 (Démarrer)
3. L'environnement Flox sera créé automatiquement
