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

# Configuration initiale
APP_DIR="/var/www/gepetto"
TEMP_DIR="/tmp/gepetto-temp"
REPO_URL="https://github.com/Ramzibenchaabane/Gepetto-front.git"

# Nettoyage initial
log "Nettoyage des répertoires temporaires..."
rm -rf "$TEMP_DIR"
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

# Installation de PM2
log "Installation de PM2..."
npm install -g pm2 || error "Échec de l'installation de PM2"

# Préparation des répertoires
log "Préparation des répertoires..."
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

# Configuration des variables d'environnement
log "Configuration des variables d'environnement..."
sudo -u www-data cat > "$APP_DIR/.env.local" << EOL
NEXT_PUBLIC_API_URL=http://66.114.112.70
NEXT_PUBLIC_API_PORT=22186
NEXT_PUBLIC_API_ENDPOINT=/generate
EOL

# Build de l'application
log "Build de l'application..."
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

# Configuration et démarrage avec PM2
log "Configuration et démarrage avec PM2..."
cd "$APP_DIR"
sudo -u www-data pm2 delete gepetto 2>/dev/null || true
sudo -u www-data pm2 start npm --name "gepetto" -- start || error "Échec du démarrage de l'application"
sudo -u www-data pm2 startup || error "Échec de la configuration du démarrage automatique"
env PATH=$PATH:/usr/bin pm2 startup systemd -u www-data --hp /var/www || error "Échec de la configuration systemd"
sudo -u www-data pm2 save || error "Échec de la sauvegarde de la configuration PM2"

# Configuration des logs PM2
log "Configuration des logs PM2..."
mkdir -p /var/log/pm2
chown www-data:www-data /var/log/pm2
chmod 755 /var/log/pm2

# Vérification finale
log "Vérification du service..."
if ! systemctl is-active --quiet nginx; then
    error "Nginx n'est pas en cours d'exécution"
fi

if ! sudo -u www-data pm2 list | grep -q "gepetto"; then
    error "L'application n'est pas en cours d'exécution"
fi

# Affichage des informations finales
IP_ADDRESS=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
log "✅ Déploiement terminé avec succès!"
log "📝 Logs Nginx: /var/log/nginx/gepetto-*.log"
log "📝 Logs PM2: pm2 logs gepetto"
log "🌐 L'application devrait être accessible sur http://${IP_ADDRESS}"

# Affichage des logs pour vérification
log "📜 Dernières lignes des logs..."
sudo -u www-data pm2 logs gepetto --lines 10