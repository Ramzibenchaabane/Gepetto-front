#!/bin/bash

# Arrêt du script en cas d'erreur
set -e

# Fonction pour afficher les messages
log() {
    echo -e "\e[34m🚀 $1\e[0m"
}

# Fonction pour afficher les erreurs
error() {
    echo -e "\e[31m❌ $1\e[0m"
    exit 1
}

# Fonction pour lire la configuration du backend
configure_backend() {
    local DEFAULT_API_URL="http://66.114.112.70"
    local DEFAULT_API_PORT="22186"
    local DEFAULT_API_ENDPOINT="/generate"
    
    echo -e "\e[33m⚙️  Configuration du Backend\e[0m"
    read -p "Voulez-vous modifier l'URL du backend ? (O/N) : " MODIFY_BACKEND
    
    if [[ "${MODIFY_BACKEND,,}" == "o" ]]; then
        # Lecture de l'IP
        while true; do
            read -p "Entrez l'IP du backend (ex: 66.114.112.70) : " BACKEND_IP
            if [[ $BACKEND_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                break
            else
                echo "Format d'IP invalide. Veuillez réessayer."
            fi
        done
        
        # Lecture du port
        while true; do
            read -p "Entrez le port du backend (ex: 22186) : " BACKEND_PORT
            if [[ $BACKEND_PORT =~ ^[0-9]+$ ]] && [ $BACKEND_PORT -ge 1 ] && [ $BACKEND_PORT -le 65535 ]; then
                break
            else
                echo "Port invalide. Veuillez entrer un nombre entre 1 et 65535."
            fi
        done
        
        API_URL="http://${BACKEND_IP}"
        API_PORT="${BACKEND_PORT}"
    else
        API_URL="${DEFAULT_API_URL}"
        API_PORT="${DEFAULT_API_PORT}"
    fi
    
    log "Configuration backend :"
    log "URL: ${API_URL}"
    log "Port: ${API_PORT}"
    log "Endpoint: ${DEFAULT_API_ENDPOINT}"
}

# Vérification que le script est exécuté avec sudo
if [ "$EUID" -ne 0 ]; then 
    error "Ce script doit être exécuté avec sudo"
fi

# Vérification de l'espace disque
MIN_SPACE_GB=10
AVAILABLE_SPACE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
if [ "$AVAILABLE_SPACE" -lt "$MIN_SPACE_GB" ]; then
    error "Espace disque insuffisant. ${AVAILABLE_SPACE}GB disponible, ${MIN_SPACE_GB}GB requis"
fi

# Configuration des chemins
APP_DIR="/var/www/gepetto"
TEMP_DIR="/tmp/gepetto-temp"
PM2_ROOT="/var/www/.pm2"
REPO_URL="https://github.com/Ramzibenchaabane/Gepetto-front.git"

# Appel de la fonction de configuration du backend
configure_backend

# Nettoyage initial
log "Nettoyage des répertoires temporaires..."
rm -rf "$TEMP_DIR"
rm -rf "$PM2_ROOT"
mkdir -p "$TEMP_DIR"

# Installation des dépendances système
log "Installation des dépendances système..."
apt-get update || error "Échec de la mise à jour du système"
apt-get install -y nodejs npm git nginx || error "Échec de l'installation des dépendances"

# Installation de Node.js LTS
log "Installation de Node.js LTS..."
curl -fsSL https://deb.nodesource.com/setup_18.x | bash - || error "Échec de la configuration de Node.js"
apt-get install -y nodejs || error "Échec de l'installation de Node.js"

# Vérification des versions
log "Vérification des versions installées..."
node --version || error "Node.js n'est pas installé correctement"
npm --version || error "npm n'est pas installé correctement"

# Configuration de PM2
log "Configuration de PM2..."
npm uninstall -g pm2 2>/dev/null || true
npm install -g pm2 || error "Échec de l'installation de PM2"

# Préparation des répertoires PM2
log "Préparation des répertoires PM2..."
mkdir -p "$PM2_ROOT"/{logs,pids,modules}
touch "$PM2_ROOT"/pm2.log
touch "$PM2_ROOT"/module_conf.json
chown -R www-data:www-data "$PM2_ROOT"
chmod -R 755 "$PM2_ROOT"

# Préparation des répertoires de l'application
log "Préparation des répertoires de l'application..."
mkdir -p "$APP_DIR"
chown -R www-data:www-data "$APP_DIR"
chmod -R 755 "$APP_DIR"

# Configuration du cache npm
log "Configuration du cache npm..."
mkdir -p /var/www/.npm
chown -R www-data:www-data /var/www/.npm
chmod -R 755 /var/www/.npm

# Clonage du repository
log "Clonage du repository..."
cd "$TEMP_DIR"
git clone "$REPO_URL" || error "Échec du clonage du repository"

# Copie des fichiers
log "Copie des fichiers de l'application..."
rm -rf "$APP_DIR"/*
cp -r "$TEMP_DIR/Gepetto-front/gepetto/"* "$APP_DIR/"
cp -r "$TEMP_DIR/Gepetto-front/gepetto/".* "$APP_DIR/" 2>/dev/null || true
chown -R www-data:www-data "$APP_DIR"

# Nettoyage du répertoire temporaire
log "Nettoyage du répertoire temporaire..."
rm -rf "$TEMP_DIR"

# Installation des dépendances du projet
log "Installation des dépendances du projet..."
cd "$APP_DIR"
sudo -u www-data npm cache clean --force
sudo -u www-data rm -rf node_modules package-lock.json
sudo -u www-data npm install || error "Échec de l'installation des dépendances"

# Installation de sharp pour l'optimisation des images
log "Installation de sharp..."
sudo -u www-data npm install sharp || error "Échec de l'installation de sharp"

# Configuration des variables d'environnement
log "Configuration des variables d'environnement..."
sudo -u www-data cat > "$APP_DIR/.env.local" << EOL
NEXT_PUBLIC_API_URL=${API_URL}
NEXT_PUBLIC_API_PORT=${API_PORT}
NEXT_PUBLIC_API_ENDPOINT=/generate
EOL

# Configuration de next.config.js
log "Mise à jour de la configuration Next.js..."
sudo -u www-data cat > "$APP_DIR/next.config.js" << EOL
/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  async rewrites() {
    return [
      {
        source: '/api/:path*',
        destination: '${API_URL}:${API_PORT}/:path*'
      }
    ]
  }
}

module.exports = nextConfig
EOL

# Build de l'application
log "Build de l'application..."
cd "$APP_DIR"
sudo -u www-data npm run build || error "Échec du build de l'application"

# Configuration Nginx
log "Configuration de Nginx..."
cat > /etc/nginx/sites-available/gepetto << EOL
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    access_log /var/log/nginx/gepetto-access.log;
    error_log /var/log/nginx/gepetto-error.log;
}
EOL

# Activation de la configuration Nginx
log "Activation de la configuration Nginx..."
ln -sf /etc/nginx/sites-available/gepetto /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t || error "Configuration Nginx invalide"
systemctl restart nginx || error "Échec du redémarrage de Nginx"

# Démarrage de l'application avec PM2
log "Démarrage de l'application avec PM2..."
cd "$APP_DIR"
sudo -u www-data PM2_HOME="$PM2_ROOT" pm2 delete all 2>/dev/null || true
sudo -u www-data PM2_HOME="$PM2_ROOT" pm2 start npm --name "gepetto" -- start || error "Échec du démarrage de l'application"

# Configuration du démarrage automatique
log "Configuration du démarrage automatique..."
sudo env PATH=$PATH:/usr/bin PM2_HOME="$PM2_ROOT" pm2 startup systemd -u www-data --hp /var/www || error "Échec de la configuration systemd"
sudo -u www-data PM2_HOME="$PM2_ROOT" pm2 save || error "Échec de la sauvegarde de la configuration PM2"

# Vérification finale
log "Vérification des services..."
if ! systemctl is-active --quiet nginx; then
    error "Nginx n'est pas en cours d'exécution"
fi

if ! sudo -u www-data PM2_HOME="$PM2_ROOT" pm2 list | grep -q "gepetto"; then
    error "L'application n'est pas en cours d'exécution"
fi

# Récupération de l'IP
IP_ADDRESS=$(hostname -I | awk '{print $1}')
if [ -z "$IP_ADDRESS" ]; then
    IP_ADDRESS="votre-ip-serveur"
fi

# Affichage des informations finales
log "✅ Déploiement terminé avec succès!"
log "📝 Logs Nginx: /var/log/nginx/gepetto-*.log"
log "📝 Logs PM2: sudo -u www-data PM2_HOME=$PM2_ROOT pm2 logs gepetto"
log "🌐 L'application devrait être accessible sur http://${IP_ADDRESS}"

# Affichage des logs pour vérification
log "📜 Dernières lignes des logs..."
sudo -u www-data PM2_HOME="$PM2_ROOT" pm2 logs gepetto --lines 10