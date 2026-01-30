#!/bin/bash

# Load shared library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# Vérifier si gum est installé
if ! command -v gum &> /dev/null; then
    echo "gum n'est pas installé. Installation..."
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
    echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
    sudo apt update && sudo apt install -y gum
fi

# Fonction principale avec boucle
main() {
    # Check prerequisites on first run
    if ! check_prerequisites; then
        exit 1
    fi

    while true; do
        clear

        # Titre stylisé
        gum style \
            --foreground 212 --border-foreground 212 --border double \
            --align center --width 50 --margin "1 2" --padding "1 2" \
            "BuildFlowz" "Menu Interactif avec Gum"

        # Display session identity if enabled
        if [ "$BUILDFLOWZ_SESSION_ENABLED" = "true" ]; then
            init_session 2>/dev/null
            local session_id=$(get_session_id 2>/dev/null)
            if [ -n "$session_id" ]; then
                local hash_art=$(generate_hash_art "$session_id" 2>/dev/null)
                local session_code=$(get_session_code "$session_id" 2>/dev/null)
                local user="${USER:-unknown}"
                local host="${HOSTNAME:-$(hostname 2>/dev/null || echo 'unknown')}"

                # Display session banner with gum
                echo ""
                gum style \
                    --foreground 141 --border-foreground 141 --border rounded \
                    --align center --width 50 --padding "0 2" \
                    "Session Identity"

                # Display hash art
                echo "$hash_art" | gum style --foreground 45 --align center --width 50

                # Display user info and session code
                gum style \
                    --foreground 82 --align center --width 50 \
                    "$user@$host    $session_code"
                echo ""
            fi
        fi

        # Menu de sélection
        CHOICE=$(gum choose "📁 Naviguer dans /root" "📋 Lister les environnements" "🌐 Afficher les URLs" "🛑 Stopper un environnement" "📝 Ouvrir le répertoire de code" "🚀 Déployer un repo GitHub" "🗑️ Supprimer un environnement"             "🚀 Démarrer un environnement" \
            "🚀 Démarrer un environnement (custom path)" \
            "🌐 Publier sur le web" "🔍 Basculer l'inspecteur web" "👋 Quitter")

        case $CHOICE in
            "📁 Naviguer dans /root")
                gum style --foreground 45 "📁 Dossiers disponibles dans /root"
                
                FOLDERS=$(find /root -maxdepth 1 -type d ! -name ".*" ! -path /root | sort)
                
                if [ -z "$FOLDERS" ]; then
                    gum style --foreground 196 "❌ Aucun dossier trouvé"
                else
                    SELECTED=$(echo "$FOLDERS" | gum choose)
                    
                    if [ -n "$SELECTED" ]; then
                        gum style --foreground 82 "📁 Dossier sélectionné: $SELECTED"
                        
                        if gum confirm "Ouvrir un shell dans ce dossier ?"; then
                            cd "$SELECTED" && exec $SHELL
                        fi
                    fi
                fi
                ;;
            "📋 Lister les environnements")
                gum style \
                    --foreground 45 --border-foreground 45 --border rounded \
                    --align center --width 50 --padding "0 2" \
                    "Environnements PM2"
                
                gum spin --spinner dot --title "Chargement des environnements..." -- sleep 0.5
                
                ALL_ENVS=$(list_all_environments)
                
                if [ -z "$ALL_ENVS" ]; then
                    gum style --foreground 196 "❌ Aucun environnement trouvé"
                else
                    echo ""
                    while IFS= read -r name; do
                        pm2_status=$(get_pm2_status "$name")
                        project_dir=$(resolve_project_path "$name")
                        
                        # Afficher le statut avec gum style
                        case "$pm2_status" in
                            "online")
                                gum style --foreground 82 "🟢 [ONLINE] $name"
                                ;;
                            "stopped")
                                gum style --foreground 226 "🟡 [STOPPED] $name"
                                ;;
                            "errored"|"error")
                                gum style --foreground 196 "🔴 [ERROR] $name"
                                ;;
                            "pm2-not-installed")
                                gum style --foreground 196 "❌ [PM2 NOT INSTALLED] $name"
                                ;;
                            *)
                                gum style --foreground 45 "⚪ [${pm2_status^^}] $name"
                                ;;
                        esac
                        
                        # Afficher le répertoire du projet
                        if [ -n "$project_dir" ]; then
                            gum style --foreground 33 "   📂 $project_dir"
                            
                            # Afficher si environnement Flox présent
                            if [ -d "$project_dir/.flox" ]; then
                                gum style --foreground 82 "   ✅ Flox activé"
                            fi
                        fi
                        
                        # Afficher le port si disponible
                        port=$(get_port_from_pm2 "$name")
                        if [ -n "$port" ]; then
                            gum style --foreground 45 "   🔌 Port: $port"
                        fi
                        echo ""
                    done <<< "$ALL_ENVS"
                fi
                ;;
            "🌐 Afficher les URLs")
                gum style \
                    --foreground 33 --border-foreground 33 --border rounded \
                    --align center --width 50 --padding "0 2" \
                    "URLs des environnements"
                
                ALL_ENVS=$(list_all_environments)
                
                if [ -z "$ALL_ENVS" ]; then
                    gum style --foreground 196 "❌ Aucun environnement trouvé"
                else
                    echo ""
                    SELECTED_ENV=$(echo "$ALL_ENVS" | gum choose --header "Choisissez un environnement:")
                    
                    if [ -n "$SELECTED_ENV" ]; then
                        echo ""
                        gum style --foreground 82 "🌐 URLs pour $SELECTED_ENV"
                        
                        PORT=$(get_port_from_pm2 "$SELECTED_ENV")
                        
                        if [ -n "$PORT" ]; then
                            echo ""
                            gum style --foreground 45 "  • http://localhost:${PORT}"
                        else
                            echo ""
                            gum style --foreground 226 "  ⚠️  Projet non démarré ou port non assigné"
                        fi
                    fi
                fi
                ;;
            "🛑 Stopper un environnement")
                gum style \
                    --foreground 196 --border-foreground 196 --border rounded \
                    --align center --width 50 --padding "0 2" \
                    "Stopper un environnement"
                
                ALL_ENVS=$(list_all_environments)
                
                if [ -z "$ALL_ENVS" ]; then
                    gum style --foreground 196 "❌ Aucun environnement trouvé"
                else
                    echo ""
                    SELECTED_ENV=$(echo "$ALL_ENVS" | gum filter --placeholder "Rechercher un environnement...")
                    
                    if [ -n "$SELECTED_ENV" ]; then
                        echo ""
                        if gum confirm "Arrêter $SELECTED_ENV ?"; then
                            gum spin --spinner dot --title "Arrêt de $SELECTED_ENV..." -- env_stop "$SELECTED_ENV"
                            echo ""
                            gum style --foreground 82 "✅ Environnement $SELECTED_ENV arrêté !"
                        fi
                    fi
                fi
                ;;
            "📝 Ouvrir le répertoire de code")
                gum style \
                    --foreground 33 --border-foreground 33 --border rounded \
                    --align center --width 50 --padding "0 2" \
                    "Ouvrir le répertoire de code"
                
                ALL_ENVS=$(list_all_environments)
                
                if [ -z "$ALL_ENVS" ]; then
                    gum style --foreground 196 "❌ Aucun environnement trouvé"
                else
                    echo ""
                    SELECTED_ENV=$(echo "$ALL_ENVS" | gum filter --placeholder "Rechercher un environnement...")
                    
                    if [ -n "$SELECTED_ENV" ]; then
                        PROJECT_DIR="$PROJECTS_DIR/$SELECTED_ENV"
                        
                        if [ -d "$PROJECT_DIR" ]; then
                            gum style --foreground 82 "📂 Répertoire: $PROJECT_DIR"
                            
                            if gum confirm "Ouvrir un shell dans ce dossier ?"; then
                                cd "$PROJECT_DIR" && exec $SHELL
                            fi
                        else
                            gum style --foreground 196 "❌ Répertoire introuvable: $PROJECT_DIR"
                        fi
                    fi
                fi
                ;;
            "🚀 Déployer un repo GitHub")
                gum style \
                    --foreground 82 --border-foreground 82 --border rounded \
                    --align center --width 50 --padding "0 2" \
                    "Déployer un repo GitHub"
                
                echo ""
                gum spin --spinner dot --title "Recherche de vos repos GitHub..." -- sleep 0.5
                
                GITHUB_REPOS=$(list_github_repos)
                
                if [ -z "$GITHUB_REPOS" ]; then
                    gum style --foreground 196 "❌ Aucun repo trouvé ou erreur d'authentification"
                else
                    echo ""
                    SELECTED_REPO=$(echo "$GITHUB_REPOS" | cut -d':' -f1 | gum filter --placeholder "Rechercher un repo...")

                    if [ -n "$SELECTED_REPO" ]; then
                        # Validate repo name
                        if ! validate_repo_name "$SELECTED_REPO"; then
                            gum style --foreground 196 "❌ Invalid repository name"
                            continue
                        fi

                        PROJECT_NAME="${SELECTED_REPO,,}"
                        PROJECT_DIR="$PROJECTS_DIR/$PROJECT_NAME"
                        
                        echo ""
                        gum style --foreground 82 "📦 Repo sélectionné: $SELECTED_REPO"
                        
                        # Vérifier si le projet existe déjà
                        if [ -d "$PROJECT_DIR" ]; then
                            echo ""
                            gum style --foreground 226 "⚠️  Le projet $PROJECT_NAME existe déjà"
                            
                            if gum confirm "Voulez-vous le remplacer ?"; then
                                env_remove "$PROJECT_NAME"
                            else
                                gum style --foreground 45 "❌ Annulé"
                                continue
                            fi
                        fi
                        
                        echo ""
                        mkdir -p "$PROJECT_DIR"
                        
                        # Cloner le repo
                        GITHUB_USER=$(get_github_username)
                        gum spin --spinner dot --title "Clonage de $SELECTED_REPO..." -- git clone "https://github.com/$GITHUB_USER/$SELECTED_REPO.git" "$PROJECT_DIR" 2>/dev/null
                        
                        if [ ! -d "$PROJECT_DIR/.git" ]; then
                            gum style --foreground 196 "❌ Erreur lors du clonage"
                            rm -rf "$PROJECT_DIR"
                        else
                            gum style --foreground 82 "✅ Repo cloné avec succès"
                            
                            # Initialiser l'environnement Flox
                            echo ""
                            gum spin --spinner dot --title "Initialisation de l'environnement Flox..." -- init_flox_env "$PROJECT_DIR" "$PROJECT_NAME"
                            
                            if [ $? -ne 0 ]; then
                                gum style --foreground 196 "❌ Échec de l'initialisation Flox"
                                rm -rf "$PROJECT_DIR"
                            else
                                # Démarrer l'environnement
                                echo ""
                                gum spin --spinner dot --title "Démarrage du projet..." -- env_start "$PROJECT_NAME"
                                
                                PORT=$(get_port_from_pm2 "$PROJECT_NAME")
                                
                                echo ""
                                gum style --foreground 82 "✅ Déploiement réussi !"
                                
                                if [ -n "$PORT" ]; then
                                    echo ""
                                    gum style --foreground 45 "🌐 URL: http://localhost:${PORT}"
                                fi
                                
                                echo ""
                                gum style --foreground 226 "📝 Code dans: $PROJECT_DIR"
                            fi
                        fi
                    fi
                fi
                ;;
            "🗑️ Supprimer un environnement")
                gum style \
                    --foreground 196 --border-foreground 196 --border rounded \
                    --align center --width 50 --padding "0 2" \
                    "Supprimer un environnement"
                
                ALL_ENVS=$(list_all_environments)
                
                if [ -z "$ALL_ENVS" ]; then
                    gum style --foreground 196 "❌ Aucun environnement trouvé"
                else
                    echo ""
                    SELECTED_ENV=$(echo "$ALL_ENVS" | gum filter --placeholder "Rechercher un environnement...")
                    
                    if [ -n "$SELECTED_ENV" ]; then
                        echo ""
                        gum style --foreground 196 "⚠️  ATTENTION : Cette action est irréversible !"
                        gum style --foreground 226 "Projet: $SELECTED_ENV"
                        gum style --foreground 226 "Dossier: $PROJECTS_DIR/$SELECTED_ENV"
                        echo ""
                        
                        if gum confirm "Confirmer la suppression ?"; then
                            gum spin --spinner dot --title "Suppression de $SELECTED_ENV..." -- env_remove "$SELECTED_ENV"
                            echo ""
                            gum style --foreground 82 "✅ Projet $SELECTED_ENV supprimé avec succès !"
                        else
                            gum style --foreground 45 "❌ Annulé"
                        fi
                    fi
                fi
                ;;
            "🚀 Démarrer un environnement")
                gum style \
                    --foreground 82 --border-foreground 82 --border rounded \
                    --align center --width 50 --padding "0 2" \
                    "Démarrer un environnement"
                
                ALL_ENVS=$(list_all_environments)
                
                if [ -z "$ALL_ENVS" ]; then
                    gum style --foreground 196 "❌ Aucun environnement trouvé"
                else
                    echo ""
                    SELECTED_ENV=$(echo "$ALL_ENVS" | gum filter --placeholder "Rechercher un environnement...")
                    
                    if [ -n "$SELECTED_ENV" ]; then
                        gum spin --spinner dot --title "Démarrage de $SELECTED_ENV..." -- env_start "$SELECTED_ENV"
                        
                        echo ""
                        gum style --foreground 82 "✅ Projet démarré avec succès ou mis à jour !"
                        
                        PROJECT_DIR=$(resolve_project_path "$SELECTED_ENV")
                        ENV_NAME=$(basename "$PROJECT_DIR") # Assuming project name is the last part of the path for PM2
                        
                        PORT=$(get_port_from_pm2 "$ENV_NAME")
                        if [ -n "$PORT" ]; then
                            echo ""
                            gum style --foreground 45 "🌐 URL: http://localhost:${PORT}"
                            gum style --foreground 226 "📝 Code dans: $PROJECT_DIR"
                        else
                            echo ""
                            gum style --foreground 226 "⚠️  Port non assigné ou non détecté"
                            gum style --foreground 226 "📝 Code dans: $PROJECT_DIR"
                        fi
                    fi
                fi
                ;;
            "🚀 Démarrer un environnement (custom path)")
                gum style \
                    --foreground 82 --border-foreground 82 --border rounded \
                    --align center --width 50 --padding "0 2" \
                    "Démarrer un environnement (custom path)"
                echo ""
                CUSTOM_PATH=$(gum input --placeholder "Entrez le chemin absolu du projet (ex: /root/my-robots/chatbot)")
                if [ -z "$CUSTOM_PATH" ]; then
                    gum style --foreground 196 "❌ Chemin requis"
                elif ! validate_project_path "$CUSTOM_PATH" 2>&1 | while read -r line; do gum style --foreground 196 "$line"; done; then
                    gum input --placeholder "Appuyez sur Entrée pour continuer..."
                else
                    gum spin --spinner dot --title "Démarrage du projet à partir de $CUSTOM_PATH..." -- env_start "$CUSTOM_PATH"
                    echo ""
                    gum style --foreground 82 "✅ Projet démarré avec succès ou mis à jour !"
                    
                    PROJECT_DIR=$(resolve_project_path "$CUSTOM_PATH")
                    if [ -n "$PROJECT_DIR" ]; then
                        ENV_NAME=$(basename "$PROJECT_DIR") # This assumes project name is the last part of the path
                        PORT=$(get_port_from_pm2 "$ENV_NAME")
                        if [ -n "$PORT" ]; then
                            echo ""
                            gum style --foreground 45 "🌐 URL: http://localhost:${PORT}"
                        else
                            echo ""
                            gum style --foreground 226 "⚠️  Port non assigné ou non détecté"
                        fi
                        echo ""
                        gum style --foreground 226 "📝 Code dans: $PROJECT_DIR"
                    else
                        gum style --foreground 196 "❌ Impossible de résoudre le répertoire du projet pour $CUSTOM_PATH"
                    fi
                fi
                ;;
            "🌐 Publier sur le web")
                gum style \
                    --foreground 45 --border-foreground 45 --border rounded \
                    --align center --width 50 --padding "0 2" \
                    "Publication Web (Caddy + DuckDNS)"
                
                # Vérifier Caddy
                if ! command -v caddy &> /dev/null; then
                    gum style --foreground 196 "❌ Caddy n'est pas installé"
                    gum style --foreground 226 "Lancez: sudo ./install.sh"
                    continue
                fi
                
                # Vérifier PM2
                if ! command -v pm2 &> /dev/null; then
                    gum style --foreground 196 "❌ PM2 n'est pas installé"
                    continue
                fi
                
                # Récupérer l'IP publique
                echo ""
                PUBLIC_IP=$(gum spin --spinner dot --title "Détection de l'IP publique..." -- curl -4 -s https://ip.me 2>/dev/null)
                
                if [ -z "$PUBLIC_IP" ]; then
                    gum style --foreground 196 "❌ Impossible de récupérer l'IP publique"
                    continue
                fi
                
                gum style --foreground 82 "✅ IP publique détectée: $PUBLIC_IP"
                echo ""
                
                # Configuration DuckDNS
                gum style --foreground 45 "🦆 Configuration DuckDNS"
                echo ""
                gum style --foreground 33 "Votre URL sera: votresubdomain.duckdns.org"
                gum style --foreground 226 "Créez un compte gratuit sur https://www.duckdns.org"
                echo ""
                
                SUBDOMAIN=$(gum input --placeholder "Sous-domaine DuckDNS (ex: demo, dev)")
                if [ -z "$SUBDOMAIN" ]; then
                    gum style --foreground 196 "❌ Sous-domaine requis"
                    continue
                fi
                
                echo ""
                TOKEN=$(gum input --placeholder "Token DuckDNS" --password)
                if [ -z "$TOKEN" ]; then
                    gum style --foreground 196 "❌ Token requis"
                    continue
                fi
                
                # Mise à jour DuckDNS
                echo ""
                DUCKDNS_RESPONSE=$(gum spin --spinner dot --title "Mise à jour DuckDNS..." -- curl -s "https://www.duckdns.org/update?domains=$SUBDOMAIN&token=$TOKEN&ip=$PUBLIC_IP")
                
                if [ "$DUCKDNS_RESPONSE" != "OK" ]; then
                    gum style --foreground 196 "❌ Erreur DuckDNS: $DUCKDNS_RESPONSE"
                    gum style --foreground 226 "Vérifiez votre sous-domaine et token"
                    continue
                fi
                
                gum style --foreground 82 "✅ DuckDNS configuré: $SUBDOMAIN.duckdns.org → $PUBLIC_IP"
                echo ""
                
                # Récupérer les ports PM2
                APPS=$(gum spin --spinner dot --title "Détection des applications PM2..." -- pm2 jlist 2>/dev/null | python3 -c "
import sys, json
try:
    apps = json.load(sys.stdin)
    for app in apps:
        if app['pm2_env']['status'] == 'online':
            env = app['pm2_env'].get('env', {})
            port = env.get('PORT') or env.get('port')
            if port:
                name = app['name']
                print(f'{name}:{port}')
except:
    pass
" 2>/dev/null)
                
                if [ -z "$APPS" ]; then
                    gum style --foreground 196 "❌ Aucune application PM2 trouvée"
                    continue
                fi
                
                # Générer le Caddyfile
                CADDYFILE="/etc/caddy/Caddyfile"
                
                # Backup de l'ancien fichier
                if [ -f "$CADDYFILE" ]; then
                    sudo cp "$CADDYFILE" "${CADDYFILE}.backup.$(date +%s)"
                fi
                
                # Créer le nouveau Caddyfile
                {
                    echo "# Auto-généré par BuildFlowz - $(date)"
                    echo ""
                    
                    echo "$APPS" | while IFS=: read -r name port; do
                        echo "${SUBDOMAIN}.duckdns.org/${name} {"
                        echo "    reverse_proxy localhost:${port}"
                        echo "}"
                        echo ""
                    done
                } | sudo tee "$CADDYFILE" > /dev/null
                
                # Recharger Caddy
                echo ""
                if gum spin --spinner dot --title "Rechargement de Caddy..." -- sudo systemctl reload caddy 2>/dev/null || sudo caddy reload --config "$CADDYFILE" 2>/dev/null; then
                    gum style --foreground 82 "✅ Caddy configuré et rechargé"
                else
                    gum style --foreground 226 "⚠️  Erreur lors du rechargement de Caddy"
                    gum style --foreground 226 "Configuration sauvegardée dans $CADDYFILE"
                fi
                
                echo ""
                gum style --foreground 45 "🌐 URLs disponibles:"
                echo ""
                
                echo "$APPS" | while IFS=: read -r name port; do
                    gum style --foreground 82 "  ✓ https://${SUBDOMAIN}.duckdns.org/${name}"
                done
                
                echo ""
                gum style --foreground 226 "⚠️  Note: Le certificat HTTPS peut prendre quelques minutes"
                ;;
            "👋 Quitter")
                gum style --foreground 196 "Au revoir! 👋"
                exit 0
                ;;
            "🔍 Basculer l'inspecteur web")
                clear
                gum style \
                    --foreground 212 --border-foreground 212 --border double \
                    --align center --width 50 --margin "1 2" --padding "1 2" \
                    "Web Inspector" "Démarrage de l'inspecteur web"
                
                echo ""
                gum spin --spinner dot --title "Démarrage de l'inspecteur web..." -- sleep 1
                
                # Initialize web inspector
                init_web_inspector
                
                echo ""
                gum style --foreground 82 "✅ Inspecteur web démarré !"
                gum input --placeholder "Appuyez sur Entrée pour continuer..."
                ;;
        esac
        
        # Pause avant de revenir au menu
        echo ""
        gum style --foreground 226 "Appuyez sur Entrée pour revenir au menu..."
        read -r
    done
}

# Lancer le menu
main

