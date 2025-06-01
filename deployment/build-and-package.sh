#!/bin/bash

# Build and Package Script for Web Server
# このスクリプトは、ローカル環境でWebアプリケーションをビルドし、
# S3にアップロード可能なアーティファクトを作成します

set -e

echo "=== Building Web Server Application ==="

# プロジェクトのルートディレクトリに移動
cd "$(dirname "$0")/../webserver"

# 依存関係のインストール
echo "Installing dependencies..."
npm install

# フロントエンドの依存関係のインストール
echo "Installing frontend dependencies..."
cd frontend
npm install

# フロントエンドのビルド
echo "Building frontend..."
npm run build

# webserverディレクトリに戻る
cd ..

# パッケージディレクトリの作成
echo "Creating package directory..."
PACKAGE_DIR="../build/webserver-package"
rm -rf "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR"

# 必要なファイルをコピー
echo "Copying files..."
cp package.json "$PACKAGE_DIR/"
cp package-lock.json "$PACKAGE_DIR/" 2>/dev/null || echo "package-lock.json not found, skipping..."
cp server.js "$PACKAGE_DIR/"
cp .env.production "$PACKAGE_DIR/.env"
cp -r dist "$PACKAGE_DIR/" 2>/dev/null || echo "dist directory not found, skipping..."

# node_modulesは除外し、productionインストール用のpackage.jsonのみコピー

# アーティファクトの作成
echo "Creating deployment artifact..."
cd ../build
tar -czf webserver-latest.tar.gz webserver-package

echo "=== Build Completed ==="
echo "Deployment artifact created: build/webserver-latest.tar.gz"
echo ""
echo "Next steps:"
echo "1. Upload webserver-latest.tar.gz to S3:"
echo "   aws s3 cp build/webserver-latest.tar.gz s3://your-deployment-bucket/webserver/"
echo ""
echo "2. Update the S3_BUCKET and S3_OBJECT_KEY variables in ec2-webserver-userdata.sh"
echo ""
echo "3. Use ec2-webserver-userdata.sh as User Data when launching the EC2 instance"
