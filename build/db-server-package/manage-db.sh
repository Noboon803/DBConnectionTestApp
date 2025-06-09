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
