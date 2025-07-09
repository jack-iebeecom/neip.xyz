#!/bin/bash

# NEIP Ping Server Update Script
# Run this script on each ping server to update to latest version with traceroute support

set -e

REPO_URL="https://github.com/jack-iebeecom/neip.xyz.git"
SERVER_DIR="/opt/neip-ping-server"
BACKUP_DIR="/opt/neip-ping-server.backup.$(date +%Y%m%d_%H%M%S)"

echo "🔄 NEIP Ping Server Update Script"
echo "================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Please run as root (sudo ./update-server.sh)"
    exit 1
fi

# Backup current version
echo "📦 Creating backup..."
if [ -d "$SERVER_DIR" ]; then
    cp -r "$SERVER_DIR" "$BACKUP_DIR"
    echo "✅ Backup created: $BACKUP_DIR"
else
    echo "⚠️  No existing server directory found"
fi

# Stop current service
echo "⏹️  Stopping current service..."
pm2 stop neip-ping-server || echo "Service not running"

# Create temp directory for new code
TEMP_DIR="/tmp/neip-update-$(date +%s)"
mkdir -p "$TEMP_DIR"

# Clone latest code
echo "📥 Downloading latest code..."
git clone "$REPO_URL" "$TEMP_DIR"

# Copy ping-server files
echo "📋 Updating server files..."
mkdir -p "$SERVER_DIR"

# Backup current .env file
if [ -f "$SERVER_DIR/.env" ]; then
    cp "$SERVER_DIR/.env" "$TEMP_DIR/ping-server/.env.backup"
    echo "💾 Environment file backed up"
fi

# Copy new files
cp -r "$TEMP_DIR/ping-server/"* "$SERVER_DIR/"

# Restore .env if exists
if [ -f "$SERVER_DIR/.env.backup" ]; then
    mv "$SERVER_DIR/.env.backup" "$SERVER_DIR/.env"
    echo "🔧 Environment file restored"
fi

# Install/update dependencies
echo "📦 Installing dependencies..."
cd "$SERVER_DIR"
npm install --production

# Start service
echo "🚀 Starting updated service..."
pm2 start ecosystem.config.js || pm2 restart neip-ping-server

# Cleanup
echo "🧹 Cleaning up..."
rm -rf "$TEMP_DIR"

# Health check
echo "🏥 Performing health check..."
sleep 5

if pm2 list | grep -q "neip-ping-server.*online"; then
    echo "✅ Update completed successfully!"
    echo ""
    echo "📊 Service Status:"
    pm2 list | grep neip-ping-server
    echo ""
    echo "🔗 Test endpoints:"
    echo "   Health: http://$(curl -s ifconfig.me)/health"
    echo "   Ping API: http://$(curl -s ifconfig.me)/api/ping"
    echo "   🆕 Traceroute API: http://$(curl -s ifconfig.me)/api/tracert"
    echo ""
    echo "📝 View logs:"
    echo "   pm2 logs neip-ping-server"
else
    echo "❌ Update failed! Service not running"
    echo "🔄 Restoring from backup..."
    
    # Restore backup
    rm -rf "$SERVER_DIR"
    cp -r "$BACKUP_DIR" "$SERVER_DIR"
    
    cd "$SERVER_DIR"
    pm2 restart neip-ping-server
    
    echo "⚠️  Rollback completed. Check logs for errors."
    exit 1
fi

echo ""
echo "🎉 NEIP Ping Server updated with traceroute support!"
echo "💡 New features available:"
echo "   • Traceroute API endpoint: /api/tracert"
echo "   • Cross-platform support (Windows/Linux/macOS)"
echo "   • Streaming responses via Server-Sent Events"
echo "   • Enhanced error handling and logging" 