#!/bin/bash

# Couleurs pour une meilleure lisibilité
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Compteur d'erreurs
ERROR_COUNT=0
SUCCESS_COUNT=0
WARNING_COUNT=0

# Vérification des arguments
if [ "$#" -ne 1 ]; then
    echo -e "${RED}[ERREUR] Usage: $0 <chemin_vers_config.env>${NC}"
    exit 1
fi

CONFIG_FILE="$1"

# Vérification de l'existence du fichier de configuration
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}[ERREUR] Le fichier de configuration '$CONFIG_FILE' n'existe pas.${NC}"
    exit 1
fi

# Chargement de la configuration
source "$CONFIG_FILE"

# Fonction pour logger les étapes avec niveau de log
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $timestamp - $message"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $timestamp - $message"
            ((SUCCESS_COUNT++))
            ;;
        "WARNING")
            echo -e "${YELLOW}[WARNING]${NC} $timestamp - $message"
            ((WARNING_COUNT++))
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $timestamp - $message"
            ((ERROR_COUNT++))
            ;;
    esac
    
    if [ ! -z "$LOG_DIR" ]; then
        echo "$timestamp - [$level] $message" >> "$LOG_DIR/deploy.log"
    fi
}

# Fonction pour exécuter une commande avec gestion d'erreur
execute_command() {
    local command="$1"
    local description="$2"
    local error_message="$3"
    
    log "INFO" "Début: $description"
    
    if eval "$command"; then
        log "SUCCESS" "$description"
        return 0
    else
        log "ERROR" "$error_message"
        return 1
    fi
}

# Fonction pour gérer les permissions avec vérification
set_permissions() {
    local path="$1"
    local type="$2"
    local description="Configuration des permissions pour: $path"
    
    log "INFO" "$description"
    
    if [ ! -e "$path" ]; then
        log "ERROR" "Le chemin $path n'existe pas"
        return 1
    }
    
    if [ "$type" = "directory" ]; then
        execute_command "chmod $APP_DIR_MODE '$path'" \
            "Attribution des permissions du répertoire: $path" \
            "Échec de l'attribution des permissions pour le répertoire: $path"
            
        execute_command "chown $DEPLOY_USER:$NGINX_GROUP '$path'" \
            "Attribution du propriétaire pour le répertoire: $path" \
            "Échec de l'attribution du propriétaire pour le répertoire: $path"
            
        execute_command "chmod g+s '$path'" \
            "Attribution du sticky bit pour le répertoire: $path" \
            "Échec de l'attribution du sticky bit pour le répertoire: $path"
    else
        execute_command "chmod $APP_FILE_MODE '$path'" \
            "Attribution des permissions du fichier: $path" \
            "Échec de l'attribution des permissions pour le fichier: $path"
            
        execute_command "chown $DEPLOY_USER:$NGINX_GROUP '$path'" \
            "Attribution du propriétaire pour le fichier: $path" \
            "Échec de l'attribution du propriétaire pour le fichier: $path"
    fi
}

# Fonction pour vérifier les prérequis système
check_prerequisites() {
    log "INFO" "Vérification des prérequis système"
    
    # Vérification de l'espace disque
    local disk_space=$(df -h / | awk 'NR==2 {print $4}')
    if [[ ${disk_space%G*} -lt 10 ]]; then
        log "WARNING" "Espace disque faible: $disk_space restant"
    else
        log "SUCCESS" "Espace disque suffisant: $disk_space"
    fi
    
    # Vérification de la RAM
    local total_memory=$(free -g | awk 'NR==2 {print $2}')
    if [[ $total_memory -lt 4 ]]; then
        log "WARNING" "Mémoire RAM limitée: ${total_memory}GB"
    else
        log "SUCCESS" "Mémoire RAM suffisante: ${total_memory}GB"
    fi
    
    # Vérification des droits sudo
    if [[ $EUID -ne 0 ]]; then
        log "ERROR" "Ce script doit être exécuté avec les droits sudo"
        exit 1
    else
        log "SUCCESS" "Droits sudo vérifiés"
    fi
}

# Installation des dépendances système avec vérification
install_system_dependencies() {
    log "INFO" "Installation des dépendances système"
    
    execute_command "apt-get update" \
        "Mise à jour des paquets" \
        "Échec de la mise à jour des paquets"
        
    execute_command "apt-get upgrade -y" \
        "Mise à niveau des paquets" \
        "Échec de la mise à niveau des paquets"
        
    execute_command "apt-get install -y curl git nginx acl" \
        "Installation des dépendances" \
        "Échec de l'installation des dépendances"
}

# Installation de Node.js avec vérification
install_nodejs() {
    log "INFO" "Installation de Node.js ${NODE_VERSION}"
    
    if [ ! -d "/root/.nvm" ]; then
        execute_command "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash" \
            "Installation de NVM" \
            "Échec de l'installation de NVM"
            
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        
        execute_command "nvm install $NODE_VERSION" \
            "Installation de Node.js $NODE_VERSION" \
            "Échec de l'installation de Node.js"
            
        execute_command "nvm use $NODE_VERSION" \
            "Utilisation de Node.js $NODE_VERSION" \
            "Échec de l'utilisation de Node.js"
    else
        log "SUCCESS" "NVM déjà installé"
    fi
}

# Configuration de Nginx avec vérification de la syntaxe
configure_nginx() {
    log "INFO" "Configuration de Nginx"
    
    local nginx_config_path="/etc/nginx/sites-available/$APP_NAME"
    local ssl_config=""
    
    if [ "$NGINX_SSL_ENABLED" = true ]; then
        # Vérification des certificats SSL
        if [ ! -f "$SSL_CERT_PATH" ] || [ ! -f "$SSL_KEY_PATH" ]; then
            log "ERROR" "Certificats SSL manquants"
            return 1
        fi
        
        ssl_config="
        listen 443 ssl;
        ssl_certificate $SSL_CERT_PATH;
        ssl_certificate_key $SSL_KEY_PATH;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_prefer_server_ciphers off;
        "
    fi

    # Création de la configuration Nginx
    cat > "$nginx_config_path" <<EOF
server {
    listen ${NGINX_PORT};
    server_name ${NGINX_SERVER_NAME};
    
    ${ssl_config}

    root ${DEPLOY_DIR};
    index index.html;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Content-Type-Options "nosniff";
    add_header Strict-Transport-Security "max-age=31536000" always;

    location / {
        try_files \$uri \$uri/ /index.html;
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

    location ~ /\. {
        deny all;
    }
}
EOF

    # Vérification de la syntaxe Nginx
    execute_command "nginx -t" \
        "Vérification de la syntaxe Nginx" \
        "Erreur de syntaxe dans la configuration Nginx"
        
    # Activation de la configuration
    execute_command "ln -sf '$nginx_config_path' '/etc/nginx/sites-enabled/'" \
        "Activation de la configuration Nginx" \
        "Échec de l'activation de la configuration"
        
    execute_command "rm -f /etc/nginx/sites-enabled/default" \
        "Suppression de la configuration par défaut" \
        "Échec de la suppression de la configuration par défaut"
        
    # Redémarrage de Nginx
    execute_command "systemctl restart nginx" \
        "Redémarrage de Nginx" \
        "Échec du redémarrage de Nginx"
}

# Sauvegarde de l'application avec vérification
backup_application() {
    if [ -d "$DEPLOY_DIR" ]; then
        log "INFO" "Création d'une sauvegarde"
        
        local backup_file="$BACKUP_DIR/${APP_NAME}_$(date +%Y%m%d_%H%M%S).tar.gz"
        
        execute_command "tar -czf '$backup_file' -C '$DEPLOY_DIR' ." \
            "Création de l'archive de sauvegarde" \
            "Échec de la création de la sauvegarde"
            
        execute_command "set_permissions '$backup_file' 'file'" \
            "Configuration des permissions de la sauvegarde" \
            "Échec de la configuration des permissions de la sauvegarde"
            
        # Nettoyage des anciennes sauvegardes
        execute_command "cd '$BACKUP_DIR' && ls -t | tail -n +$((KEEP_BACKUPS + 1)) | xargs -r rm" \
            "Nettoyage des anciennes sauvegardes" \
            "Échec du nettoyage des anciennes sauvegardes"
    else
        log "WARNING" "Répertoire de déploiement non trouvé, pas de sauvegarde nécessaire"
    fi
}

# Création du script de déploiement avec vérification
create_deploy_script() {
    log "INFO" "Création du script de déploiement"
    
    local deploy_script="/usr/local/bin/deploy-react-app.sh"
    
    # Création du script de déploiement
    cat > "$deploy_script" <<'EOF'
#!/bin/bash
# ... [Contenu du script de déploiement avec les fonctions améliorées] ...
EOF

    execute_command "chmod +x '$deploy_script'" \
        "Attribution des permissions d'exécution" \
        "Échec de l'attribution des permissions d'exécution"
        
    execute_command "chown $DEPLOY_USER:$DEPLOY_GROUP '$deploy_script'" \
        "Attribution du propriétaire" \
        "Échec de l'attribution du propriétaire"
}

# Fonction principale avec rapport final
main() {
    local start_time=$(date +%s)
    
    log "INFO" "Début du déploiement de $APP_NAME"
    
    # Exécution des étapes avec gestion d'erreurs
    check_prerequisites || exit 1
    create_directories || exit 1
    install_system_dependencies || exit 1
    install_nodejs || exit 1
    configure_nginx || exit 1
    create_deploy_script || exit 1
    
    # Configuration finale des permissions
    set_permissions_recursive "$DEPLOY_DIR" || exit 1
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Rapport final
    echo -e "\n${BLUE}=== Rapport de déploiement ===${NC}"
    echo -e "Durée: ${duration} secondes"
    echo -e "Succès: ${GREEN}${SUCCESS_COUNT}${NC}"
    echo -e "Avertissements: ${YELLOW}${WARNING_COUNT}${NC}"
    echo -e "Erreurs: ${RED}${ERROR_COUNT}${NC}"
    
    if [ $ERROR_COUNT -eq 0 ]; then
        log "SUCCESS" "Installation terminée avec succès!"
        log "INFO" "Pour déployer l'application, utilisez: sudo /usr/local/bin/deploy-react-app.sh"
    else
        log "ERROR" "Installation terminée avec des erreurs. Veuillez vérifier les logs"
        exit 1
    fi
}

# Démarrage du script avec trap pour la gestion des erreurs
trap 'log "ERROR" "Script interrompu par le signal $?"' ERR
main