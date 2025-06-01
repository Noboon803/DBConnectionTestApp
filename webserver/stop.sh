#!/bin/bash

# Stop script for production deployment
# このスクリプトは本番環境でアプリケーションを停止します

set -e

echo "=== Stopping Web Server Application ==="

# PM2の確認
if command -v pm2 &> /dev/null; then
    # アプリケーションの停止
    echo "Stopping webserver application..."
    pm2 stop webserver || echo "Application was not running"
    
    # アプリケーションの削除
    echo "Removing webserver from PM2..."
    pm2 delete webserver || echo "Application was not registered"
    
    # PM2の状態確認
    pm2 list
    
    echo "=== Web Server Stopped Successfully ==="
else
    echo "PM2 not found. Attempting to stop Node.js processes..."
    pkill -f "node server.js" || echo "No Node.js processes found"
    echo "=== Process cleanup completed ==="
fi
