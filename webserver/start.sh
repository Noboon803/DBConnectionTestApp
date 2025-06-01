#!/bin/bash

# Start script for production deployment
# このスクリプトは本番環境でアプリケーションを起動します

set -e

echo "=== Starting Web Server Application ==="

# 環境変数のロード
if [ -f .env.production ]; then
    export $(cat .env.production | xargs)
    echo "Loaded production environment variables"
else
    echo "Warning: .env.production not found, using default values"
fi

# Node.jsとnpmのバージョン確認
echo "Node.js version: $(node --version)"
echo "npm version: $(npm --version)"

# PM2のインストール確認
if ! command -v pm2 &> /dev/null; then
    echo "Installing PM2..."
    npm install -g pm2
fi

# プロダクション依存関係のインストール
echo "Installing production dependencies..."
npm ci --only=production

# ログディレクトリの作成
mkdir -p logs

# データベース接続テスト
echo "Testing database connection..."
node test-db-connection.js

# PM2でアプリケーションを起動
echo "Starting application with PM2..."
pm2 start ecosystem.config.json

# PM2の状態確認
pm2 list

echo "=== Web Server Started Successfully ==="
echo "Application is running on port ${PORT:-3000}"
echo "Use 'pm2 logs webserver' to view logs"
echo "Use 'pm2 stop webserver' to stop the application"
