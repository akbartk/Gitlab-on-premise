#!/bin/bash
# ============================================
# GitLab CE Management Script
# ============================================
# Script untuk mengelola GitLab CE Docker Compose
#
# Penggunaan:
#   ./scripts/manage.sh [command]
#
# Commands:
#   start     - Start GitLab
#   stop      - Stop GitLab
#   restart   - Restart GitLab
#   status    - Cek status container
#   logs      - Lihat log GitLab
#   fix       - Fix socket permission
#   backup    - Buat backup
#   password  - Lihat/reset password root
#   shell     - Masuk ke shell container
# ============================================

# Warna
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Load .env jika ada
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

COMMAND=${1:-help}

case "$COMMAND" in
    start)
        log_info "Starting GitLab..."
        docker-compose up -d
        log_success "GitLab started!"
        echo ""
        log_info "Tunggu 60 detik lalu jalankan: $0 fix"
        ;;

    stop)
        log_info "Stopping GitLab..."
        docker-compose down
        log_success "GitLab stopped!"
        ;;

    restart)
        log_info "Restarting GitLab..."
        docker-compose restart
        sleep 60
        $0 fix
        log_success "GitLab restarted!"
        ;;

    status)
        echo "Container Status:"
        docker-compose ps
        echo ""
        echo "HTTP Status:"
        HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${GITLAB_HTTP_PORT:-8880}/ 2>/dev/null || echo "N/A")
        echo "  http://localhost:${GITLAB_HTTP_PORT:-8880}/ -> HTTP $HTTP_STATUS"
        ;;

    logs)
        SERVICE=${2:-gitlab}
        log_info "Showing logs for $SERVICE (Ctrl+C to exit)..."
        docker-compose logs -f --tail=100 $SERVICE
        ;;

    fix)
        log_info "Fixing socket permissions..."

        # Fix directory permissions
        docker exec gitlab chmod 755 /var/opt/gitlab/gitlab-workhorse/ 2>/dev/null || true
        docker exec gitlab chmod 755 /var/opt/gitlab/gitlab-rails/ 2>/dev/null || true

        # Fix socket directory permissions
        docker exec gitlab chmod 777 /var/opt/gitlab/gitlab-workhorse/sockets/ 2>/dev/null || true
        docker exec gitlab chmod 777 /var/opt/gitlab/gitlab-rails/sockets/ 2>/dev/null || true

        # Fix socket permissions
        docker exec gitlab chmod 777 /var/opt/gitlab/gitlab-workhorse/sockets/socket 2>/dev/null || true
        docker exec gitlab chmod 777 /var/opt/gitlab/gitlab-rails/sockets/gitlab.socket 2>/dev/null || true

        # Restart gitlab-workhorse agar socket baru dibuat
        log_info "Restarting gitlab-workhorse..."
        docker exec gitlab gitlab-ctl restart gitlab-workhorse 2>/dev/null || true
        sleep 5

        # Fix socket permission lagi setelah restart
        docker exec gitlab chmod 777 /var/opt/gitlab/gitlab-workhorse/sockets/socket 2>/dev/null || true
        docker exec gitlab chmod 777 /var/opt/gitlab/gitlab-rails/sockets/gitlab.socket 2>/dev/null || true

        log_success "Socket permissions fixed!"

        # Test
        HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${GITLAB_HTTP_PORT:-8880}/ 2>/dev/null || echo "000")
        echo ""
        if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "302" ]; then
            log_success "GitLab accessible! (HTTP $HTTP_STATUS)"
        else
            log_error "GitLab not accessible (HTTP $HTTP_STATUS)"
        fi
        ;;

    backup)
        log_info "Creating GitLab backup..."
        docker exec gitlab gitlab-backup create
        log_success "Backup created!"
        echo ""
        ls -la data/gitlab/backups/ 2>/dev/null || echo "Backup location: data/gitlab/backups/"
        ;;

    password)
        echo "============================================"
        echo "         ROOT PASSWORD INFORMATION"
        echo "============================================"
        echo ""
        echo "Generated Password (jika ada):"
        docker exec gitlab cat /etc/gitlab/initial_root_password 2>/dev/null || echo "  File tidak ditemukan"
        echo ""
        echo "Untuk reset password:"
        echo "  docker exec -it gitlab gitlab-rake 'gitlab:password:reset[root]'"
        echo ""
        ;;

    shell)
        SERVICE=${2:-gitlab}
        log_info "Entering $SERVICE shell..."
        docker exec -it $SERVICE /bin/bash
        ;;

    reconfigure)
        log_info "Reconfiguring GitLab..."
        docker exec gitlab gitlab-ctl reconfigure
        sleep 30
        $0 fix
        log_success "Reconfigure complete!"
        ;;

    update)
        log_info "Pulling latest images..."
        docker-compose pull
        log_info "Restarting with new images..."
        docker-compose up -d
        sleep 60
        $0 fix
        log_success "Update complete!"
        ;;

    clean)
        log_warning "This will remove all data! Are you sure?"
        read -p "Type 'yes' to confirm: " confirm
        if [ "$confirm" = "yes" ]; then
            log_info "Stopping containers..."
            docker-compose down -v
            log_info "Removing data..."
            rm -rf data/*
            log_success "Cleanup complete!"
        else
            log_info "Cancelled."
        fi
        ;;

    help|*)
        echo "============================================"
        echo "   GitLab CE Management Script"
        echo "============================================"
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  start       Start GitLab containers"
        echo "  stop        Stop GitLab containers"
        echo "  restart     Restart GitLab containers"
        echo "  status      Check container status"
        echo "  logs        View logs (optional: service name)"
        echo "  fix         Fix socket permissions"
        echo "  backup      Create GitLab backup"
        echo "  password    Show/reset root password"
        echo "  shell       Enter container shell"
        echo "  reconfigure Reconfigure GitLab"
        echo "  update      Update to latest images"
        echo "  clean       Remove all data (dangerous!)"
        echo "  help        Show this help"
        echo ""
        echo "Examples:"
        echo "  $0 status"
        echo "  $0 logs postgres"
        echo "  $0 fix"
        echo ""
        ;;
esac
