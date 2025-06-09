#!/bin/bash
set -e  # エラー時に自動的に異常終了

#
# 変数設定
#
# s3://S3_BUCKET/S3_PREFIX下にweb-server-packageフォルダの中身をアップロードしておく
#
S3_BUCKET="dbconnectiontestapp-deployment"
S3_PREFIX="webserver"
DB_HOST="10.0.2.100"
DB_PORT="3306"
DB_USER="testuser"
DB_PASSWORD="PassPass123!Hoge"
DB_NAME="testdb"

#
# STEP1 : システム環境を更新
#
yum update -y

#
# STEP2 : Node.js 18.xをインストール
#
curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
yum install -y nodejs

#
# STEP3 : PM2をインストール
#
npm install -g pm2

#
# STEP4 : AWS CLIをインストール
#
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

#
# STEP5 : アプリケーションディレクトリを設定
#
APP_DIR="/opt/webserver"
mkdir -p "$APP_DIR"
cd "$APP_DIR"

#
# STEP6 : S3からアプリケーションをダウンロード
#
aws s3 sync s3://${S3_BUCKET}/${S3_PREFIX}/　"$APP_DIR/"

#
# STEP7 : 本番環境用依存関係をインストール
#
npm ci --production

#
# STEP8 : 環境変数を設定
#
cat > "$APP_DIR/.env" << EOF
DB_HOST=${DB_HOST}
DB_PORT=${DB_PORT}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
DB_NAME=${DB_NAME}
PORT=3000
NODE_ENV=production
LOG_LEVEL=info
EOF

chmod 600 "$APP_DIR/.env"

#
# STEP9 : データベース接続テスト
#
node test-db-connection.js || echo "Database connection test failed (DB server may still be starting)"

#
# STEP10 : アプリケーション権限を設定
#
mkdir -p "$APP_DIR/logs"
chown -R ec2-user:ec2-user "$APP_DIR"

#
# STEP11 : PM2でアプリケーションを起動
#
cd "$APP_DIR"
sudo -u ec2-user pm2 start ecosystem.config.json --env production
sudo -u ec2-user pm2 startup systemd -u ec2-user --hp /home/ec2-user
sudo -u ec2-user pm2 save

#
# STEP12 : Nginxをインストール&設定
#
yum install -y nginx

# Nginxの設定
cat > /etc/nginx/conf.d/webserver.conf << 'EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    location /static/ {
        alias /opt/webserver/dist/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup
cat > /etc/nginx/nginx.conf << 'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    include /etc/nginx/conf.d/*.conf;
}
EOF

#
# STEP13 : Nginxを起動
#
systemctl enable nginx
systemctl start nginx

echo "WebServer deployment completed"
