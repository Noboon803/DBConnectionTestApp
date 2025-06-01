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
