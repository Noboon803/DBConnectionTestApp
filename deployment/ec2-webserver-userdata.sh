#!/bin/bash

# EC2 User Data Script for Web Server
# このスクリプトは、EC2インスタンスの起動時に実行され、
# S3からアプリケーションをダウンロードしてデプロイします

# ログファイルの設定
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "=== Starting Web Server Deployment ==="
echo "Timestamp: $(date)"

# システムの更新
echo "Updating system packages..."
yum update -y

# Node.js 18.x のインストール
echo "Installing Node.js..."
curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
yum install -y nodejs

# PM2 のグローバルインストール（プロセス管理用）
echo "Installing PM2..."
npm install -g pm2

# AWS CLI のインストール（既にインストールされている場合はスキップ）
echo "Checking AWS CLI..."
if ! command -v aws &> /dev/null; then
    echo "Installing AWS CLI..."
    yum install -y awscli
fi

# アプリケーション用ディレクトリの作成
echo "Creating application directory..."
mkdir -p /opt/webserver
cd /opt/webserver

# S3からアプリケーションアーティファクトをダウンロード
# 注意: 実際のデプロイ時は、以下のS3バケット名とオブジェクトキーを適切な値に変更してください
S3_BUCKET="your-deployment-bucket"
S3_OBJECT_KEY="webserver/webserver-latest.tar.gz"

echo "Downloading application from S3..."
aws s3 cp s3://${S3_BUCKET}/${S3_OBJECT_KEY} /tmp/webserver.tar.gz

# アーティファクトの展開
echo "Extracting application..."
tar -xzf /tmp/webserver.tar.gz -C /opt/webserver --strip-components=1

# 依存関係のインストール
echo "Installing dependencies..."
npm install --production

# 環境変数ファイルの設定
echo "Setting up environment variables..."
cat > /opt/webserver/.env << EOF
# Production Database Configuration
# 注意: 実際のデプロイ時は、以下の値を実際のDBサーバーの情報に置き換えてください
DB_HOST=10.0.2.100
DB_PORT=3306
DB_USER=ec2user
DB_PASSWORD=production_password
DB_NAME=productiondb

# Server Configuration
PORT=80
NODE_ENV=production
EOF

# アプリケーションの所有者を設定
echo "Setting up permissions..."
chown -R ec2-user:ec2-user /opt/webserver

# PM2でアプリケーションを起動
echo "Starting application with PM2..."
cd /opt/webserver
sudo -u ec2-user pm2 start server.js --name "webserver" --env production

# PM2の自動起動設定
echo "Setting up PM2 auto-startup..."
sudo -u ec2-user pm2 startup systemd
sudo -u ec2-user pm2 save

# セキュリティグループでポート80を開放する必要があります
echo "=== Web Server Deployment Completed ==="
echo "Application should be accessible on port 80"
echo "Logs can be found at: /var/log/user-data.log"
echo "PM2 logs: pm2 logs webserver"
