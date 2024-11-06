#!/bin/bash

# Arrêt du script en cas d'erreur
set -e

echo "🚀 Démarrage du déploiement de Gepetto..."

# Installation des dépendances système
echo "📦 Installation des dépendances système..."
sudo apt update
sudo apt install -y nodejs npm git nginx

# Installation de la dernière version LTS de Node.js
echo "🔄 Installation de Node.js LTS..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# Vérification des versions
echo "ℹ️ Versions installées:"
node --version
npm --version

# Installation de PM2 globalement
echo "📊 Installation de PM2..."
sudo npm install -g pm2

# Préparation du répertoire temporaire dans /tmp
echo "📁 Préparation du répertoire temporaire..."
sudo rm -rf /tmp/gepetto-temp
sudo mkdir -p /tmp/gepetto-temp
sudo chown -R ubuntu:ubuntu /tmp/gepetto-temp

# Clonage dans le répertoire temporaire
echo "📥 Clonage du repository..."
cd /tmp/gepetto-temp
git clone https://github.com/Ramzibenchaabane/Gepetto-front.git

# Préparation du répertoire de déploiement
echo "📁 Préparation du répertoire de déploiement..."
sudo mkdir -p /var/www/gepetto
sudo rm -rf /var/www/gepetto/*
sudo chown -R www-data:www-data /var/www/gepetto
sudo chmod -R 755 /var/www/gepetto

# Copie des fichiers
echo "📦 Copie des fichiers..."
sudo cp -r /tmp/gepetto-temp/Gepetto-front/gepetto/* /var/www/gepetto/
sudo cp -r /tmp/gepetto-temp/Gepetto-front/gepetto/.* /var/www/gepetto/ 2>/dev/null || true
sudo chown -R www-data:www-data /var/www/gepetto

# Nettoyage du répertoire temporaire
sudo rm -rf /tmp/gepetto-temp

# Installation des dépendances du projet
echo "📚 Installation des dépendances du projet..."
cd /var/www/gepetto
sudo -u www-data npm install

# Configuration des variables d'environnement
echo "🔒 Configuration des variables d'environnement..."
sudo -u www-data cat > .env.local << EOL
NEXT_PUBLIC_API_URL=http://66.114.112.70
NEXT_PUBLIC_API_PORT=22186
NEXT_PUBLIC_API_ENDPOINT=/generate
EOL

# Build de l'application
echo "🏗️ Build de l'application..."
sudo -u www-data npm run build

# Configuration Nginx
echo "🔧 Configuration de Nginx..."
sudo cat > /etc/nginx/sites-available/gepetto << EOL
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
}
EOL

# Activation de la configuration Nginx
sudo ln -sf /etc/nginx/sites-available/gepetto /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl restart nginx

# Configuration et démarrage avec PM2
echo "🚦 Démarrage de l'application avec PM2..."
cd /var/www/gepetto
sudo -u www-data pm2 delete gepetto 2>/dev/null || true
sudo -u www-data pm2 start npm --name "gepetto" -- start
sudo -u www-data pm2 startup
sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u www-data --hp /var/www
sudo -u www-data pm2 save

# Configuration des permissions pour les logs PM2
sudo mkdir -p /var/log/pm2
sudo chown www-data:www-data /var/log/pm2

echo "✅ Déploiement terminé! L'application devrait être accessible sur http://[ip-ec2]"

# Affichage des logs pour vérification
echo "📜 Affichage des logs..."
sudo -u www-data pm2 logs gepetto --lines 10