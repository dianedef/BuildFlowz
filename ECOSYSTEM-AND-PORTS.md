# 🔌 Gestion automatique des ports et ecosystem PM2

## 📋 Vue d'ensemble

BuildFlowz gère automatiquement les ports et crée des fichiers `ecosystem.config.cjs` persistants pour chaque projet, garantissant que les tunnels SSH locaux détectent tous les projets.

---

## 🎯 Problème résolu

### Avant ❌
- Fichier PM2 temporaire dans `/tmp/` supprimé après démarrage
- Variable `PORT` non persistante dans PM2
- Script tunnel SSH local ne trouvait pas les projets
- Risque de collision de ports

### Après ✅
- Fichier permanent `ecosystem.config.cjs` dans chaque projet
- Format CommonJS (`.cjs`) compatible avec `"type": "module"`
- Variable `PORT` correctement définie et persistante
- Allocation intelligente des ports (anti-collision)
- Script tunnel SSH local détecte automatiquement tous les projets

---

## 🏗️ Format du fichier généré

Lors du démarrage d'un projet avec BuildFlowz, un fichier `ecosystem.config.cjs` est automatiquement créé :

```javascript
module.exports = {
  apps: [{
    name: "nom-du-projet",
    cwd: "/root/nom-du-projet",
    script: "bash",
    args: ["-c", "export PORT=3000 && flox activate -- npm run dev -- --port 3000"],
    env: {
      PORT: 3000  // ← Variable PORT définie et persistante
    },
    autorestart: true,
    watch: false
  }]
};
```

---

## 🔌 Allocation automatique des ports

### Comment ça fonctionne ?

Quand vous démarrez un nouveau projet, BuildFlowz :

1. **Détecte les ports déjà utilisés** (double vérification) :
   - ✅ Ports actifs en écoute (serveurs running)
   - ✅ Ports assignés dans PM2 (même si arrêtés)

2. **Trouve le prochain port disponible** :
   ```
   3000 → déjà pris (webinde)
   3001 → déjà pris (winflowz)
   3002 → déjà pris (tubeflow)
   3003 → LIBRE ! ✅ ← Assigné au nouveau projet
   ```

3. **Crée l'ecosystem.config.cjs** avec le port trouvé

### Sécurité anti-collision

✅ **Scénario 1** : Port actif (serveur running)  
→ Détecté par `is_port_in_use()` → Skip

✅ **Scénario 2** : Port assigné dans PM2 mais arrêté  
→ Détecté par `get_all_pm2_ports()` → Skip

✅ **Scénario 3** : Port complètement libre  
→ Assigné au nouveau projet → Success !

### Range de ports

- **Port de départ** : 3000
- **Port maximum** : 3100 (100 ports disponibles)
- **Si tous occupés** : Erreur avec message explicite

---

## ✅ Vérification

### Lister tous les ports assignés dans PM2

```bash
pm2 jlist | python3 -c "
import sys, json
apps = json.load(sys.stdin)
for app in apps:
    env = app['pm2_env'].get('env', {})
    port = env.get('PORT', 'NOT SET')
    status = app['pm2_env']['status']
    print(f'{app[\"name\"]}: PORT={port} ({status})')
"
```

**Exemple de résultat** :
```
webinde: PORT=3000 (online)
winflowz: PORT=3001 (online)
tubeflow: PORT=3002 (errored)
test-project: PORT=3001 (stopped)
```

### Trouver le prochain port disponible

```bash
source /root/BuildFlowz/lib.sh
find_available_port 3000
# Résultat: 3003 (ou le premier port libre)
```

---

## 🚀 Workflow complet - Nouveau projet

### 1. Cloner un nouveau projet
```bash
cd /root
git clone https://github.com/user/nouveau-projet.git
```

### 2. Démarrer avec BuildFlowz
Le script automatiquement :
- Détecte les ports 3000, 3001, 3002 déjà pris
- Assigne le port 3003 au nouveau projet
- Crée `ecosystem.config.cjs` avec `PORT=3003`
- Démarre le serveur avec PM2

### 3. Vérifier
```bash
pm2 list
# → nouveau-projet sur port 3003 ✅

pm2 env <id>
# → PORT: 3003 ✅
```

### 4. Tunnel SSH local (machine locale)
```bash
# Sur votre machine locale
urls  # ou ./menu_local.sh

# Choisir option 1: Démarrer les tunnels
# Le script détecte automatiquement nouveau-projet avec PORT=3003 !
```

### 5. Accéder dans le navigateur
```
http://localhost:3003
```

---

## 🔧 Fonctions disponibles (lib.sh)

### `get_all_pm2_ports()`
Retourne tous les ports assignés dans PM2 (même arrêtés)

### `is_port_in_use(port)`
Vérifie si un port est actuellement en écoute

### `find_available_port(base_port)`
Trouve le premier port disponible à partir de `base_port`

---

## 📝 Notes importantes

- ✅ **Pas de collision** : Le système vérifie toujours avant d'assigner un port
- ✅ **Persistant** : Le fichier `ecosystem.config.cjs` reste dans le projet
- ✅ **Compatible** : Format `.cjs` compatible avec projets ESM (`"type": "module"`)
- ✅ **Automatique** : Tout se fait lors du `env_start()` dans lib.sh
- ✅ **Détectable** : Le tunnel SSH local voit tous les projets avec `PORT` défini

---

## 🎉 Résultat

**Plus de problème de tunnel SSH qui ne trouve pas les projets !**  
**Plus de collision de ports !**  
**Tout est automatique et transparent !**
