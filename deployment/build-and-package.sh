#!/bin/bash
set -e

PROJECT_ROOT="$(dirname "$0")/.."
cd "$PROJECT_ROOT"

#
# STEP1 : フロントエンドの依存関係とビルド
#
cd webserver/frontend
npm install
npm run build
cd ..

#
# STEP2 : Webサーバーの依存関係インストール
#
npm install

#
# STEP3 : パッケージディレクトリの作成
#
PACKAGE_DIR="../build/webserver-package"
rm -rf "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR"

#
# STEP4 : 必要なファイルをコピー
#
cp package.json "$PACKAGE_DIR/"
cp package-lock.json "$PACKAGE_DIR/" 2>/dev/null || true
cp server.js "$PACKAGE_DIR/"
cp test-db-connection.js "$PACKAGE_DIR/"
cp ecosystem.config.json "$PACKAGE_DIR/"
cp .env.production "$PACKAGE_DIR/.env" 2>/dev/null || echo "No .env.production found, skipping..."
cp -r dist "$PACKAGE_DIR/" 2>/dev/null || echo "No dist directory found, skipping..."

