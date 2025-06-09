set -e

PROJECT_ROOT="$(dirname "$0")/.."
cd "$PROJECT_ROOT"

# 
# STEP1 : パッケージディレクトリの作成
#
echo "Creating package directory..."

PACKAGE_DIR="build/db-server-package"
rm -rf "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR"

#
# STEP2 : docker-compose.ymlを作成
#
echo "Creating docker-compose.yml..."

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
      - ./logs:/var/log/mysql
    command: --default-authentication-plugin=mysql_native_password --general-log=1 --general-log-file=/var/log/mysql/general.log
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

#
# STEP3 : DB初期化用SQLをコピー
# 
# dbserverフォルダ下のinit.sqlをそのまま出力します
#
echo "Copying init.sql..."

cp dbserver/init.sql "$PACKAGE_DIR/"

#
# STEP4 : 環境変数テンプレートを作成
#
echo "Creating .env.template..."

cat > "$PACKAGE_DIR/.env.template" << 'EOF'
MYSQL_ROOT_PASSWORD=RootPass456!Hoge
MYSQL_DATABASE=testdb
MYSQL_USER=testuser
MYSQL_PASSWORD=PassPass123!Hoge
EOF

#
# STEP5 : DB管理用スクリプトを作成
# 
echo "Creating manage-db.sh..."

cat > "$PACKAGE_DIR/manage-db.sh" << 'EOF'
#!/bin/bash

# DB Server management script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

case "${1:-}" in
    "start")
        echo "🚀 Starting MySQL database server..."
        docker-compose up -d
        echo "Database server started"
        echo "Check logs with: $0 logs"
        ;;
    "stop")
        echo "Stopping MySQL database server..."
        docker-compose down
        echo "Database server stopped"
        ;;
    "logs")
        echo "Showing database logs..."
        docker-compose logs -f mysql
        ;;
    "status")
        echo "Database server status:"
        docker-compose ps
        echo ""
        echo "Health check:"
        docker-compose exec mysql mysqladmin ping -h localhost || echo "Database not responding"
        ;;
    *)
        echo "Usage: $0 {start|stop|logs|status}"
        exit 1
        ;;
esac
EOF

