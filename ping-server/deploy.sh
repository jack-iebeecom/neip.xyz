#!/bin/bash

# NEIP Ping Server Deployment Script
# Run this script on Ubuntu server with root privileges

set -e

SERVER_NAME=${1:-"Tokyo"}
API_KEY=${2:-"$(openssl rand -hex 32)"}
PORT=${3:-3001}

echo "🚀 Deploying NEIP Ping Server for $SERVER_NAME"
echo "📍 Port: $PORT"

# Update system
echo "📦 Updating system packages..."
apt update && apt upgrade -y

# Install Node.js 18
echo "📦 Installing Node.js 18..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
apt install -y nodejs

# Install PM2 globally
echo "📦 Installing PM2..."
npm install -g pm2

# Create app directory
echo "📁 Creating application directory..."
mkdir -p /opt/neip-ping-server
cd /opt/neip-ping-server

# Copy application files (assume they're already uploaded)
echo "📋 Application files should be uploaded to /opt/neip-ping-server"
echo "   Run: rsync -avz ping-server/ user@server:/opt/neip-ping-server/"

# Install dependencies
echo "📦 Installing dependencies..."
npm install --production

# Create environment file
echo "⚙️ Creating environment configuration..."
cat > .env << EOF
PORT=$PORT
API_KEY=$API_KEY
SERVER_NAME=$SERVER_NAME
ALLOWED_ORIGINS=https://neip.xyz,https://www.neip.xyz
NODE_ENV=production
EOF

# Create PM2 ecosystem file
echo "⚙️ Creating PM2 configuration..."
cat > ecosystem.config.js << EOF
module.exports = {
  apps: [{
    name: 'neip-ping-server',
    script: 'server.js',
    instances: 'max',
    exec_mode: 'cluster',
    env: {
      NODE_ENV: 'production',
      PORT: $PORT
    },
    error_file: '/var/log/neip-ping-server/error.log',
    out_file: '/var/log/neip-ping-server/out.log',
    log_file: '/var/log/neip-ping-server/combined.log',
    time: true,
    max_memory_restart: '1G',
    node_args: '--max-old-space-size=1024'
  }]
};
EOF

# Create log directory
echo "📁 Creating log directory..."
mkdir -p /var/log/neip-ping-server
chmod 755 /var/log/neip-ping-server

# Set up firewall
echo "🔥 Configuring firewall..."
ufw allow $PORT/tcp
ufw allow ssh
ufw --force enable

# Start application with PM2
echo "🚀 Starting application..."
pm2 start ecosystem.config.js
pm2 save
pm2 startup

# Install nginx (reverse proxy)
echo "🌐 Installing and configuring Nginx..."
apt install -y nginx

# Create Nginx configuration
cat > /etc/nginx/sites-available/neip-ping-server << EOF
server {
    listen 80;
    server_name _;
    
    location /health {
        proxy_pass http://localhost:$PORT/health;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
    
    location /api/ {
        proxy_pass http://localhost:$PORT/api/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # SSE specific headers
        proxy_buffering off;
        proxy_cache off;
        proxy_set_header Connection '';
        proxy_http_version 1.1;
        chunked_transfer_encoding off;
    }
    
    location / {
        return 200 '{"status":"healthy","server":"$SERVER_NAME"}';
        add_header Content-Type application/json;
    }
}
EOF

# Enable site
ln -sf /etc/nginx/sites-available/neip-ping-server /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx

echo "✅ Deployment completed!"
echo ""
echo "🎯 Server Information:"
echo "   Name: $SERVER_NAME"
echo "   Port: $PORT"
echo "   API Key: $API_KEY"
echo ""
echo "🔗 Test endpoints:"
echo "   Health: http://$(curl -s ifconfig.me)/health"
echo "   Info: http://$(curl -s ifconfig.me)/api/info"
echo ""
echo "📊 Management commands:"
echo "   pm2 status"
echo "   pm2 logs neip-ping-server"
echo "   pm2 restart neip-ping-server"
echo "   pm2 stop neip-ping-server"
echo ""
echo "⚠️  Please save the API key: $API_KEY"
echo "⚠️  Update your main application's GLOBAL_SERVERS configuration with this server's public IP" 