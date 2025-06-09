#!/bin/bash
set -e

#
# 変数設定
#
# s3://S3_BUCKET/S3_PREFIX下にdb-server-packageフォルダの中身をアップロードしておく
#
S3_BUCKET="dbconnectiontestapp-deployment"
S3_PREFIX="db-server-package"

#
# STEP1 : システム環境を更新
#
yum update -y

#
# STEP2 : Dockerをインストール&起動
#
amazon-linux-extras install docker -y
service docker start
usermod -a -G docker ec2-user
systemctl enable docker

#
# STEP3 : docker-composeをインストール
#
DOCKER_COMPOSE_VERSION="2.37.0"
curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

#
# STEP4 : AWS CLIをインストール
#
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

#
# STEP5 : MySQLサーバーのディレクトを設定 
#
MYSQL_DIR="/opt/mysql"
mkdir -p "$MYSQL_DIR"
cd "$MYSQL_DIR"

#
# STEP6 : S3からアプリケーションをダウンロード
#
aws s3 sync s3://${S3_BUCKET}/${S3_PREFIX}/ "$MYSQL_DIR/"

#
# STEP7 : ダウンロードしたパッケージを使用環境に合わせてセットアップ
#
mv .env.template .env
chmod 600 .env
chmod +x manage-db.sh
chown ec2-user:ec2-user manage-db.sh
chown -R ec2-user:ec2-user "$MYSQL_DIR"

#
# STEP8 : MySQLコンテナを起動
#
docker-compose up -d

RETRY_COUNT=0
MAX_RETRIES=30

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if docker-compose exec -T mysql mysqladmin ping -h localhost --silent; then
        break
    else
        sleep 10
        RETRY_COUNT=$((RETRY_COUNT + 1))
    fi
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    exit 1
fi

#
# STEP9 : MySQLコンテナを自動起動化
#
cat > /etc/systemd/system/mysql-docker.service << EOF
[Unit]
Description=MySQL Docker Compose Service
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/mysql
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

systemctl enable mysql-docker.service

echo "DBServer deployment completed"