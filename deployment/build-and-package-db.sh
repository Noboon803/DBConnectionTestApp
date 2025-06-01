#!/bin/bash

# DB Server configuration packaging script
# db-serverの設定をEC2デプロイ用にパッケージング

set -e

echo "=== Packaging DB Server Configuration ==="

PROJECT_ROOT="$(dirname "$0")/.."
cd "$PROJECT_ROOT"

# パッケージディレクトリの作成
PACKAGE_DIR="build/db-server-package"
rm -rf "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR"

echo "📦 Creating production DB server configuration..."

# 本番用のdocker-compose.ymlを作成
cat > "$PACKAGE_DIR/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  mysql:
    image: mysql:8.0
    container_name: production-mysql-db
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD:-production_root_password_change_me}
      MYSQL_DATABASE: ${MYSQL_DATABASE:-testdb}
      MYSQL_USER: ${MYSQL_USER:-testuser}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD:-production_password_change_me}
    ports:
      - "3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql:ro
    command: --default-authentication-plugin=mysql_native_password
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      timeout: 20s
      retries: 10
    networks:
      - db_network

volumes:
  mysql_data:
    driver: local

networks:
  db_network:
    driver: bridge
EOF

# 本番用の初期化SQLをコピー（db-serverから）
cp db-server/init.sql "$PACKAGE_DIR/"

# 本番用の環境変数テンプレートを作成
cat > "$PACKAGE_DIR/.env.template" << 'EOF'
# Production MySQL Configuration
# Copy this file to .env and update the values

MYSQL_ROOT_PASSWORD=your_secure_root_password_here
MYSQL_DATABASE=testdb
MYSQL_USER=testuser
MYSQL_PASSWORD=your_secure_user_password_here

# Optional: MySQL tuning parameters
# MYSQL_INNODB_BUFFER_POOL_SIZE=128M
# MYSQL_MAX_CONNECTIONS=100
EOF

# 管理用スクリプトを作成
cat > "$PACKAGE_DIR/manage-db.sh" << 'EOF'
#!/bin/bash

# DB Server management script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

case "${1:-help}" in
    "start")
        echo "🚀 Starting MySQL database server..."
        docker-compose up -d
        echo "✅ Database server started"
        echo "💡 Check logs with: $0 logs"
        ;;
    "stop")
        echo "🛑 Stopping MySQL database server..."
        docker-compose down
        echo "✅ Database server stopped"
        ;;
    "restart")
        echo "🔄 Restarting MySQL database server..."
        docker-compose restart
        echo "✅ Database server restarted"
        ;;
    "logs")
        echo "📋 Showing database logs..."
        docker-compose logs -f mysql
        ;;
    "status")
        echo "📊 Database server status:"
        docker-compose ps
        echo ""
        echo "🏥 Health check:"
        docker-compose exec mysql mysqladmin ping -h localhost || echo "❌ Database not responding"
        ;;
    "backup")
        BACKUP_FILE="backup_$(date +%Y%m%d_%H%M%S).sql"
        echo "💾 Creating database backup: $BACKUP_FILE"
        docker-compose exec mysql mysqldump -u root -p${MYSQL_ROOT_PASSWORD} --all-databases > "$BACKUP_FILE"
        echo "✅ Backup created: $BACKUP_FILE"
        ;;
    "shell")
        echo "🔧 Opening MySQL shell..."
        docker-compose exec mysql mysql -u root -p
        ;;
    "help"|*)
        echo "📖 DB Server Management Commands:"
        echo "  $0 start    - Start the database server"
        echo "  $0 stop     - Stop the database server"
        echo "  $0 restart  - Restart the database server"
        echo "  $0 logs     - Show database logs"
        echo "  $0 status   - Show server status and health"
        echo "  $0 backup   - Create database backup"
        echo "  $0 shell    - Open MySQL shell"
        echo "  $0 help     - Show this help"
        ;;
esac
EOF

chmod +x "$PACKAGE_DIR/manage-db.sh"

# デプロイ用のREADMEを作成
cat > "$PACKAGE_DIR/README.md" << 'EOF'
# Production MySQL Database Server

このパッケージは、EC2インスタンスでMySQLデータベースサーバーを実行するための設定ファイルです。

## セットアップ手順

### 1. 環境変数の設定

```bash
# .env.templateをコピーして設定
cp .env.template .env

# .envファイルを編集してパスワードを設定
nano .env
```

### 2. データベースサーバーの起動

```bash
# 管理スクリプトで起動
./manage-db.sh start

# または直接docker-composeで起動
docker-compose up -d
```

### 3. 動作確認

```bash
# ステータス確認
./manage-db.sh status

# ログ確認
./manage-db.sh logs
```

## 管理コマンド

```bash
./manage-db.sh start    # データベース開始
./manage-db.sh stop     # データベース停止
./manage-db.sh restart  # データベース再起動
./manage-db.sh logs     # ログ表示
./manage-db.sh status   # ステータス確認
./manage-db.sh backup   # バックアップ作成
./manage-db.sh shell    # MySQLシェル
```

## セキュリティ注意事項

1. `.env`ファイルのパスワードは必ず変更してください
2. ファイアウォール設定でポート3306へのアクセスを制限してください
3. 定期的なバックアップを実行してください

## トラブルシューティング

### データベースが起動しない場合
```bash
# ログを確認
./manage-db.sh logs

# コンテナの状態確認
docker ps -a

# ディスク容量確認
df -h
```

### 接続エラーの場合
```bash
# ネットワーク確認
docker network ls

# ポート確認
netstat -tuln | grep 3306
```
EOF

echo "📋 Package contents:"
ls -la "$PACKAGE_DIR"

echo ""
echo "✅ DB Server Configuration Packaged Successfully!"
echo "📁 Package location: build/db-server-package/"
echo ""
echo "📤 Next steps:"
echo "1. Upload to S3:"
echo "   aws s3 sync build/db-server-package/ s3://your-deployment-bucket/db-server/"
echo ""
echo "2. Use deployment/ec2-dbserver-userdata.sh for DB server EC2"
echo "3. Update webserver configuration with DB server IP"
