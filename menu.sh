#!/bin/bash

# Vérifier si gum est installé
if ! command -v gum &> /dev/null; then
    echo "gum n'est pas installé. Installation..."
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
    echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
    sudo apt update && sudo apt install -y gum
fi

clear

# Titre stylisé
gum style \
    --foreground 212 --border-foreground 212 --border double \
    --align center --width 50 --margin "1 2" --padding "1 2" \
    "Menu Interactif" "Fait avec gum"

# Menu de sélection
CHOICE=$(gum choose "Afficher la date" "Infos système" "Créer une note" "Naviguer dans /root" "Docker: Lister les envs" "Docker: Ouvrir URLs" "Docker: Stopper env" "Docker: Créer env" "Publier sur le web" "Quitter")

case $CHOICE in
    "Afficher la date")
        gum style --foreground 82 "$(date '+%A %d %B %Y - %H:%M:%S')"
        ;;
    "Infos système")
        gum spin --spinner dot --title "Chargement..." -- sleep 1
        echo ""
        gum style --foreground 226 "Hostname: $(hostname)"
        gum style --foreground 226 "Kernel: $(uname -r)"
        gum style --foreground 226 "Uptime: $(uptime -p)"
        ;;
    "Créer une note")
        NOTE=$(gum input --placeholder "Écris ta note ici...")
        if [ -n "$NOTE" ]; then
            echo "$NOTE" >> ~/notes.txt
            gum style --foreground 82 "✅ Note sauvegardée dans ~/notes.txt"
        fi
        ;;
    "Naviguer dans /root")
        gum style --foreground 45 "Dossiers disponibles dans /root :"
        FOLDERS=$(find /root -maxdepth 1 -type d ! -name ".*" ! -path /root | sort)
        if [ -z "$FOLDERS" ]; then
            gum style --foreground 196 "Aucun dossier trouvé dans /root"
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
    "Docker: Lister les envs")
        gum style \
            --foreground 45 --border-foreground 45 --border rounded \
            --align center --width 40 --padding "0 2" \
            "Environnements Docker"

        gum spin --spinner dot --title "Chargement des environnements..." -- sleep 0.5

        if ! docker compose ls --format json 2>/dev/null | jq -e '. | length > 0' >/dev/null 2>&1; then
            gum style --foreground 196 "Aucun environnement actif"
        else
            echo ""
            docker compose ls --format json | jq -r '.[] | "\(.Name)\t\(.Status)\t\(.ConfigFiles)"' | while IFS=$'\t' read -r name status config; do
                if [[ $status == *"running"* ]]; then
                    status_icon="✅ running"
                    color="82"
                else
                    status_icon="🔴 stopped"
                    color="196"
                fi

                gum style --foreground "$color" "[$status_icon] $name"
                gum style --foreground 245 "    $config"
                echo ""
            done
        fi
        ;;
    "Docker: Ouvrir URLs")
        gum style \
            --foreground 33 --border-foreground 33 --border rounded \
            --align center --width 40 --padding "0 2" \
            "Ouvrir Environnements"

        running=$(docker compose ls --filter "status=running" --format json 2>/dev/null | jq -r '.[] | "\(.Name)\t\(.ConfigFiles)"')

        if [ -z "$running" ]; then
            gum style --foreground 196 "Aucun environnement en cours d'exécution"
        else
            selected=$(echo "$running" | awk '{print $1}' | gum choose)

            if [ -n "$selected" ]; then
                config=$(echo "$running" | grep "^$selected" | awk '{print $2}')
                gum style --foreground 82 "URLs disponibles pour $selected :"
                echo ""
                docker compose -f "$config" ps --format json 2>/dev/null | jq -r '.[].Publishers[]? | "🌐 http://localhost:\(.PublishedPort)\n🌐 http://164.92.221.78:\(.PublishedPort)"' | sort -u
            fi
        fi
        ;;
    "Docker: Stopper env")
        gum style \
            --foreground 196 --border-foreground 196 --border rounded \
            --align center --width 40 --padding "0 2" \
            "Stopper Environnements"

        all_envs=$(docker compose ls --format json 2>/dev/null | jq -r '.[] | "\(.Name)\t\(.Status)\t\(.ConfigFiles)"')
        running=$(echo "$all_envs" | awk '$2 ~ /running/ {print $1 "\t" $3}')

        if [ -z "$running" ]; then
            gum style --foreground 196 "Aucun environnement en cours d'exécution"
        else
            selected=$(echo "$running" | awk '{print $1}' | gum choose)

            if [ -n "$selected" ]; then
                config=$(echo "$running" | grep "^$selected" | awk '{print $2}')
                config_file=$(echo "$config" | cut -d',' -f1)

                gum spin --spinner meter --title "Arrêt de $selected..." -- docker compose -f "$config_file" stop
                gum style --foreground 82 "✅ Environnement $selected arrêté ! (RAM libérée)"
            fi
        fi
        ;;
    "Docker: Créer env")
        gum style --foreground 226 "🚧 Fonctionnalité à venir..."
        ;;
    "Publier sur le web")
        gum style \
            --foreground 45 --border-foreground 45 --border rounded \
            --align center --width 50 --padding "0 2" \
            "Publication Web (Caddy + DuckDNS)"
        
        echo ""
        
        # Vérifier Caddy
        if ! command -v caddy &> /dev/null; then
            gum style --foreground 196 "❌ Caddy n'est pas installé"
            gum style --foreground 226 "Lancez: sudo ./install.sh"
            exit 1
        fi
        
        # Vérifier PM2
        if ! command -v pm2 &> /dev/null; then
            gum style --foreground 196 "❌ PM2 n'est pas installé"
            exit 1
        fi
        
        # Récupérer l'IP publique
        PUBLIC_IP=$(curl -4 -s https://ip.me 2>/dev/null)
        if [ -z "$PUBLIC_IP" ]; then
            gum style --foreground 196 "❌ Impossible de récupérer l'IP publique"
            exit 1
        fi
        
        gum style --foreground 82 "✅ IP publique détectée: $PUBLIC_IP"
        echo ""
        
        # Demander le sous-domaine DuckDNS
        gum style --foreground 33 "🦆 Configuration DuckDNS"
        echo ""
        echo "Votre URL sera: votresubdomain.duckdns.org"
        echo "Créez un compte gratuit sur https://www.duckdns.org"
        echo ""
        
        SUBDOMAIN=$(gum input --placeholder "Sous-domaine DuckDNS (ex: demo, dev)")
        if [ -z "$SUBDOMAIN" ]; then
            gum style --foreground 196 "❌ Sous-domaine requis"
            exit 1
        fi
        
        echo ""
        TOKEN=$(gum input --placeholder "Token DuckDNS" --password)
        if [ -z "$TOKEN" ]; then
            gum style --foreground 196 "❌ Token requis"
            exit 1
        fi
        
        echo ""
        gum spin --spinner dot --title "Mise à jour DuckDNS..." -- curl -s "https://www.duckdns.org/update?domains=$SUBDOMAIN&token=$TOKEN&ip=$PUBLIC_IP" > /dev/null
        
        # Vérifier la réponse
        DUCKDNS_RESPONSE=$(curl -s "https://www.duckdns.org/update?domains=$SUBDOMAIN&token=$TOKEN&ip=$PUBLIC_IP")
        if [ "$DUCKDNS_RESPONSE" != "OK" ]; then
            gum style --foreground 196 "❌ Erreur DuckDNS: $DUCKDNS_RESPONSE"
            gum style --foreground 226 "Vérifiez votre sous-domaine et token"
            exit 1
        fi
        
        gum style --foreground 82 "✅ DuckDNS configuré: $SUBDOMAIN.duckdns.org → $PUBLIC_IP"
        echo ""
        
        # Récupérer les ports PM2
        gum style --foreground 33 "📡 Détection des applications PM2..."
        APPS=$(pm2 jlist 2>/dev/null | python3 -c "
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
            exit 1
        fi
        
        # Générer le Caddyfile
        CADDYFILE="/etc/caddy/Caddyfile"
        gum spin --spinner dot --title "Génération de la configuration Caddy..." -- sleep 1
        
        # Backup de l'ancien fichier
        if [ -f "$CADDYFILE" ]; then
            cp "$CADDYFILE" "${CADDYFILE}.backup.$(date +%s)"
        fi
        
        # Créer le nouveau Caddyfile
        echo "# Auto-généré par BuildFlowz - $(date)" > "$CADDYFILE"
        echo "" >> "$CADDYFILE"
        
        echo "$APPS" | while IFS=: read -r name port; do
            echo "${SUBDOMAIN}.duckdns.org/${name} {" >> "$CADDYFILE"
            echo "    reverse_proxy localhost:${port}" >> "$CADDYFILE"
            echo "}" >> "$CADDYFILE"
            echo "" >> "$CADDYFILE"
        done
        
        # Recharger Caddy
        gum spin --spinner dot --title "Rechargement de Caddy..." -- systemctl reload caddy 2>/dev/null || caddy reload --config "$CADDYFILE" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            gum style --foreground 82 "✅ Caddy configuré et rechargé"
        else
            gum style --foreground 196 "⚠️  Erreur lors du rechargement de Caddy"
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
    "Quitter")
        gum style --foreground 196 "Au revoir! 👋"
        exit 0
        ;;
esac
