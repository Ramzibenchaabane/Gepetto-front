#!/bin/bash

# Vérification des arguments
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <chemin_vers_config.env>"
    exit 1
fi

CONFIG_FILE="$1"

# Vérification de l'existence du fichier de configuration
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Erreur: Le fichier de configuration '$CONFIG_FILE' n'existe pas."
    exit 1
fi

# Chargement de la configuration
source "$CONFIG_FILE"

# Fonction pour logger les étapes
log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$timestamp - $1"
    if [ ! -z "$LOG_DIR" ]; then
        echo "$timestamp - $1" >> "$LOG_DIR/deploy.log"
    fi
}

# Création des répertoires nécessaires
create_directories() {
    log "Création des répertoires..."
    mkdir -p "$DEPLOY_DIR" "$BACKUP_DIR" "$LOG_DIR"
    chown -R $SUDO_USER:$SUDO_USER "$DEPLOY_DIR" "$BACKUP_DIR" "$LOG_DIR"
}

# Vérification des droits sudo
check_sudo() {
    if [[ $EUID -ne 0 ]]; then
        log "Ce script doit être exécuté avec les droits sudo"
        exit 1
    fi
}

# Installation des dépendances système
install_system_dependencies() {
    log "Installation des dépendances système..."
    apt-get update && apt-get upgrade -y
    apt-get install -y curl git nginx
}

# Installation de Node.js
install_nodejs() {
    log "Installation de Node.js ${NODE_VERSION}..."
    if [ ! -d "/root/.nvm" ]; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        nvm install "$NODE_VERSION"
        nvm use "$NODE_VERSION"
    fi
}

# Configuration de Nginx
configure_nginx() {
    log "Configuration de Nginx..."
    local ssl_config=""
    
    if [ "$NGINX_SSL_ENABLED" = true ]; then
        ssl_config="
        listen 443 ssl;
        ssl_certificate $SSL_CERT_PATH;
        ssl_certificate_key $SSL_KEY_PATH;
        # Configuration SSL supplémentaire
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_prefer_server_ciphers off;
        "
    fi

    cat > "/etc/nginx/sites-available/$APP_NAME" <<EOF
server {
    listen ${NGINX_PORT};
    server_name ${NGINX_SERVER_NAME};
    
    ${ssl_config}

    root ${DEPLOY_DIR}/build;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location /api {
        proxy_pass ${API_URL};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

    ln -sf "/etc/nginx/sites-available/$APP_NAME" "/etc/nginx/sites-enabled/"
    rm -f /etc/nginx/sites-enabled/default
    
    # Test de la configuration
    nginx -t
    systemctl restart nginx
}

# Sauvegarde de l'application existante
backup_application() {
    if [ -d "$DEPLOY_DIR" ]; then
        log "Création d'une sauvegarde..."
        local backup_file="$BACKUP_DIR/${APP_NAME}_$(date +%Y%m%d_%H%M%S).tar.gz"
        tar -czf "$backup_file" -C "$DEPLOY_DIR" .
        
        # Suppression des anciennes sauvegardes
        cd "$BACKUP_DIR" && ls -t | tail -n +$((KEEP_BACKUPS + 1)) | xargs -r rm
    fi
}

# Déploiement de l'application
create_deploy_script() {
    log "Création du script de déploiement..."
    cat > "/usr/local/bin/deploy-react-app.sh" <<EOF
#!/bin/bash
source "${CONFIG_FILE}"

cd "${DEPLOY_DIR}"

# Sauvegarde
$(declare -f backup_application)
backup_application

# Pull des dernières modifications
git pull origin "${GITHUB_BRANCH}"

# Installation des dépendances
npm install ${NPM_INSTALL_FLAGS}

# Build de l'application
npm run build

# Redémarrage de Nginx
systemctl restart nginx

echo "Déploiement terminé!"
EOF

    chmod +x "/usr/local/bin/deploy-react-app.sh"
}

# Exécution principale
main() {
    check_sudo
    create_directories
    install_system_dependencies
    install_nodejs
    configure_nginx
    create_deploy_script
    
    log "Installation terminée!"
    log "Pour déployer l'application, utilisez: sudo /usr/local/bin/deploy-react-app.sh"
}

main