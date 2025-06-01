#!/bin/bash

# EC2 User Data Script for DB Server
# db-serverの環境をEC2にデプロイするスクリプト

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "=== Starting DB Server Deployment ==="
echo "Timestamp: $(date)"
echo "Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
echo "Instance Type: $(curl -s http://169.254.169.254/latest/meta-data/instance-type)"

# 設定値（デプロイ時に編集してください）
S3_BUCKET="your-deployment-bucket"
S3_PREFIX="db-server"

# MySQL設定（強固なパスワードに変更してください）
MYSQL_ROOT_PASSWORD="your_secure_root_password_$(date +%s)"
MYSQL_DATABASE="testdb"
MYSQL_USER="testuser"
MYSQL_PASSWORD="your_secure_user_password_$(date +%s)"

echo "=== System Update ==="
yum update -y

echo "=== Installing Docker ==="
amazon-linux-extras install docker -y
service docker start
usermod -a -G docker ec2-user

# systemdでDockerの自動起動を有効化
systemctl enable docker

echo "=== Installing Docker Compose ==="
DOCKER_COMPOSE_VERSION="1.29.2"
curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

echo "=== Installing AWS CLI ==="
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

echo "=== Setting up MySQL Server Directory ==="
MYSQL_DIR="/opt/mysql"
mkdir -p "$MYSQL_DIR"
cd "$MYSQL_DIR"

echo "=== Downloading DB Server Configuration from S3 ==="
if aws s3 sync s3://${S3_BUCKET}/${S3_PREFIX}/ ./; then
    echo "✅ Successfully downloaded configuration from S3"
else
    echo "❌ Failed to download from S3, using fallback configuration"
    
    # フォールバック: 基本的な設定を直接作成
    cat > docker-compose.yml << EOF
version: '3.8'

services:
  mysql:
    image: mysql:8.0
    container_name: production-mysql-db
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    ports:
      - "3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql
    command: --default-authentication-plugin=mysql_native_password
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      timeout: 20s
      retries: 10

volumes:
  mysql_data:
    driver: local
EOF

    # 基本的な初期化SQL
    cat > init.sql << EOF
-- Basic initialization for fallback
CREATE TABLE IF NOT EXISTS connection_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    connection_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    client_info VARCHAR(255),
    status VARCHAR(50)
);

INSERT INTO connection_logs (client_info, status) VALUES 
('EC2 DB Server initialized', 'success');

CREATE TABLE IF NOT EXISTS server_info (
    id INT AUTO_INCREMENT PRIMARY KEY,
    server_name VARCHAR(100),
    server_type VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO server_info (server_name, server_type) VALUES 
('production-mysql-db', 'mysql'),
('ec2-db-server', 'mysql');

GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
EOF
fi

echo "=== Creating Environment Configuration ==="
cat > .env << EOF
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
MYSQL_DATABASE=${MYSQL_DATABASE}
MYSQL_USER=${MYSQL_USER}
MYSQL_PASSWORD=${MYSQL_PASSWORD}
EOF

# 環境変数ファイルのパーミッションを制限
chmod 600 .env

echo "=== Setting up management script permissions ==="
if [ -f "manage-db.sh" ]; then
    chmod +x manage-db.sh
    chown ec2-user:ec2-user manage-db.sh
fi

# ディレクトリの所有権を設定
chown -R ec2-user:ec2-user "$MYSQL_DIR"

echo "=== Starting MySQL Database Server ==="
# Docker Composeでサービスを起動
if docker-compose up -d; then
    echo "✅ MySQL server started successfully"
else
    echo "❌ Failed to start MySQL server"
    exit 1
fi

echo "=== Waiting for MySQL to be ready ==="
RETRY_COUNT=0
MAX_RETRIES=30

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if docker-compose exec -T mysql mysqladmin ping -h localhost --silent; then
        echo "✅ MySQL is ready!"
        break
    else
        echo "⏳ Waiting for MySQL... ($((RETRY_COUNT + 1))/$MAX_RETRIES)"
        sleep 10
        RETRY_COUNT=$((RETRY_COUNT + 1))
    fi
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "❌ MySQL failed to start within expected time"
    echo "📋 Container logs:"
    docker-compose logs mysql
    exit 1
fi

echo "=== Setting up systemd service for auto-start ==="
cat > /etc/systemd/system/mysql-docker.service << EOF
[Unit]
Description=MySQL Docker Compose Service
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${MYSQL_DIR}
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

systemctl enable mysql-docker.service

echo "=== Final Health Check ==="
echo "📊 Container Status:"
docker-compose ps

echo "🏥 MySQL Health Check:"
if docker-compose exec -T mysql mysqladmin ping -h localhost --silent; then
    echo "✅ MySQL health check passed"
    
    # データベース情報を表示
    echo "📋 Database Information:"
    docker-compose exec -T mysql mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "SELECT VERSION() as MySQL_Version, NOW() as Current_Time;"
    docker-compose exec -T mysql mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "SHOW DATABASES;"
else
    echo "❌ MySQL health check failed"
fi

echo "🔧 Management Commands:"
echo "  sudo /opt/mysql/manage-db.sh status"
echo "  sudo /opt/mysql/manage-db.sh logs"
echo "  sudo /opt/mysql/manage-db.sh restart"

echo "📡 Connection Information:"
echo "  Host: $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"
echo "  Port: 3306"
echo "  Database: ${MYSQL_DATABASE}"
echo "  Username: ${MYSQL_USER}"

# 設定情報をSSMパラメータストアに保存（オプション）
if command -v aws &> /dev/null; then
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
    
    echo "=== Saving configuration to SSM Parameter Store ==="
    aws ssm put-parameter \
        --name "/dbconnectiontest/db-server/${INSTANCE_ID}/host" \
        --value "${PRIVATE_IP}" \
        --type "String" \
        --overwrite || echo "⚠️  Could not save to SSM (permissions may be missing)"
    
    aws ssm put-parameter \
        --name "/dbconnectiontest/db-server/${INSTANCE_ID}/database" \
        --value "${MYSQL_DATABASE}" \
        --type "String" \
        --overwrite || echo "⚠️  Could not save to SSM (permissions may be missing)"
fi

echo "=== DB Server Deployment Completed Successfully ==="
echo "🎉 MySQL Database Server is ready for connections!"
echo "Deployment completed at: $(date)"
