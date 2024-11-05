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

# Fonction pour gérer les permissions
set_permissions() {
    local path="$1"
    local type="$2" # 'directory' ou 'file'
    
    log "Configuration des permissions pour: $path"
    
    if [ "$type" = "directory" ]; then
        # Set directory permissions
        chmod "$APP_DIR_MODE" "$path"
        chown "$DEPLOY_USER:$NGINX_GROUP" "$path"
        
        # Set group sticky bit pour que les nouveaux fichiers héritent du groupe
        chmod g+s "$path"
    else
        # Set file permissions
        chmod "$APP_FILE_MODE" "$path"
        chown "$DEPLOY_USER:$NGINX_GROUP" "$path"
    fi
}

# Fonction pour configurer récursivement les permissions
set_permissions_recursive() {
    local path="$1"
    log "Configuration récursive des permissions pour: $path"
    
    # Configurer les permissions du répertoire principal
    set_permissions "$path" "directory"
    
    # Configurer les permissions pour tous les sous-répertoires
    find "$path" -type d -exec bash -c 'set_permissions "$0" "directory"' {} \;
    
    # Configurer les permissions pour tous les fichiers
    find "$path" -type f -exec bash -c 'set_permissions "$0" "file"' {} \;
}

# Création des répertoires nécessaires avec permissions appropriées
create_directories() {
    log "Création des répertoires avec permissions appropriées..."
    
    # Création des répertoires principaux
    for dir in "$DEPLOY_DIR" "$BACKUP_DIR" "$LOG_DIR"; do
        mkdir -p "$dir"
        set_permissions "$dir" "directory"
    done
    
    # Configuration spéciale pour le répertoire de logs
    chmod "$LOG_DIR_MODE" "$LOG_DIR"
    touch "$LOG_DIR/deploy.log"
    chmod "$LOG_FILE_MODE" "$LOG_DIR/deploy.log"
    chown -R "$DEPLOY_USER:$NGINX_GROUP" "$LOG_DIR"
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
    apt-get install -y curl git nginx acl
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

    # Ajout des headers de sécurité
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Content-Type-Options "nosniff";

    location / {
        try_files \$uri \$uri/ /index.html;
        # Autoriser Nginx à lire les fichiers
        internal;
    }

    location /api {
        proxy_pass ${API_URL};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }

    # Bloquer l'accès aux fichiers cachés
    location ~ /\. {
        deny all;
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
        set_permissions "$backup_file" "file"
        
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
$(declare -f set_permissions)
$(declare -f set_permissions_recursive)
backup_application

# Pull des dernières modifications
git pull origin "${GITHUB_BRANCH}"

# Installation des dépendances
npm install ${NPM_INSTALL_FLAGS}

# Build de l'application
npm run build

# Configuration des permissions
set_permissions_recursive "${DEPLOY_DIR}/build"

# Redémarrage de Nginx
systemctl restart nginx

echo "Déploiement terminé!"
EOF

    chmod +x "/usr/local/bin/deploy-react-app.sh"
    chown "$DEPLOY_USER:$DEPLOY_GROUP" "/usr/local/bin/deploy-react-app.sh"
}

# Exécution principale
main() {
    check_sudo
    create_directories
    install_system_dependencies
    install_nodejs
    configure_nginx
    create_deploy_script
    
    # Configuration finale des permissions
    set_permissions_recursive "$DEPLOY_DIR"
    
    log "Installation terminée!"
    log "Pour déployer l'application, utilisez: sudo /usr/local/bin/deploy-react-app.sh"
}

main