- Flox pour gérer les environnements de développement par projet (gestionnaires de paquets, dépendances)
- PM2 pour orchestrer le démarrage/arrêt de tous les projets simultanément
- Tunnel SSH créé automaiquement pour tous les prots pour accéder aux applications depuis mon navigateur local via localhost:PORT
- Chaque projet garde un port fixe pour pouvoir mettre les URLs en favoris

1. **Configuration Flox** : Créer des environnements Flox par type de projet (exemples pour npm, pnpm, yarn, et Python) avec des templates réutilisables

**Environnements isolés** : Chaque projet a son propre environnement Flox défini dans un fichier manifest à la racine du projet. Cet environnement spécifie exactement ce dont le projet a besoin (Node.js, pnpm, Python, etc.).

**Activation par projet** : Vous entrez dans le dossier du projet et vous activez l'environnement Flox. À ce moment-là, les outils spécifiés deviennent disponibles dans votre shell, mais **uniquement pour ce projet**.

**Pas de pollution globale** : Vous n'installez rien globalement sur votre système. Si un projet a besoin de pnpm version X et un autre de pnpm version Y, pas de conflit. Chaque projet a ce qu'il lui faut.

**Facilement supprimable** : Vous supprimez le dossier du projet, l'environnement part avec. Ou vous désactivez l'environnement, et vous revenez à votre système de base.

**Partageable** : Le fichier manifest se commit avec le projet. Si vous clonez le projet ailleurs (autre serveur, autre machine), vous recréez l'environnement identique en une commande.

2. **Configuration PM2** : Un fichier ecosystem qui me permet de gérer tous mes projets. Le script doit spécifier automatiquement pour chaque projet : nom, dossier, port, commande de démarrage. 
3. PM2 lance les commandes dans le contexte de l'environnement Flox activé. Donc nos 30 projets démarrent chacun avec les bons outils, automatiquement. Avec 30 projets, Flox va vraiment nous sauver la vie pour éviter les conflits et garder tout ça maintenable.

**Contraintes :**
- Les ports doivent rester fixes entre les redémarrages
- La solution doit être simple à maintenir
- Je veux pouvoir mettre les URLs en favoris dans mon navigateur


Oui, c'est une commande. Généralement quelque chose comme `flox activate` dans le dossier du projet. Ça active l'environnement et vous met dans un shell avec les bons outils disponibles.

**Le truc important** : Dans votre configuration PM2, pour chaque projet vous spécifiez quelque chose comme : "va dans ce dossier, active l'environnement Flox, puis lance la commande de dev".

PM2 peut exécuter des commandes shell complexes, donc il peut faire : activer Flox PUIS lancer `pnpm dev` dans le bon contexte.

## En pratique

Vous n'avez pas à activer manuellement Flox pour chaque projet. Votre script `dev-start` via PM2 s'occupe de tout :
1. PM2 entre dans le dossier du projet
2. PM2 active l'environnement Flox du projet
3. PM2 lance la commande de dev dans cet environnement
4. Le processus tourne avec les bons outils

## Configuration Machine Locale

**SSH Config** (`~/.ssh/config`) :
- Alias pour votre serveur Hetzner
- Configuration de connexion (clé SSH, user, IP)

**Script `dev-tunnel`** :
- Lance autossh avec tous vos port forwards mappés
- Tourne en arrière-plan
- Maintient les tunnels actifs automatiquement

**Installation** :
- autossh (pour les tunnels)
- mosh (vous l'avez déjà)

---

## Configuration Serveur Hetzner

**Installation des outils** :
- Flox (gestion des environnements par projet)
- PM2 (orchestration des processus)
- tmux (vous l'avez déjà)
- mosh (vous l'avez déjà)

**Fichiers de configuration** :
- Un environnement Flox par projet (fichier manifest dans chaque dossier de projet)
- Un fichier ecosystem PM2 qui liste tous vos 30 projets avec : nom, dossier, port, commande d'activation Flox + commande de dev

**Scripts shell** :
- `dev-start [projet]` : démarre tout ou un projet via PM2
- `dev-stop [projet]` : arrête tout ou un projet
- `dev-status` : liste les projets actifs avec leurs ports
- `dev-logs [projet]` : affiche les logs d'un projet

---

## Workflow final

**Sur votre machine locale** : `dev-tunnel` (une fois, reste actif)

**SSH via Mosh sur Hetzner** : `dev-start` pour lancer vos projets

**Dans votre navigateur** : localhost:3000, localhost:3001, etc.
