#!/bin/bash
# ============================================
# GitLab CE Auto Setup Script
# ============================================
# Script ini akan melakukan setup otomatis GitLab CE
# Termasuk pembuatan direktori dan fix socket permission
#
# Penggunaan:
#   chmod +x scripts/setup.sh
#   ./scripts/setup.sh
# ============================================

set -e

# Warna untuk output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log function
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Banner
echo ""
echo "============================================"
echo "   GitLab CE Docker Compose Auto Setup"
echo "============================================"
echo ""

# Cek .env file
if [ ! -f .env ]; then
    log_warning "File .env tidak ditemukan!"

    if [ -f .env.example ]; then
        log_info "Membuat .env dari .env.example..."
        cp .env.example .env
        log_warning "SILAKAN EDIT FILE .env SEBELUM MELANJUTKAN!"
        log_warning "Ganti semua nilai CHANGE_THIS_* dengan nilai yang sesuai."
        echo ""
        log_info "Edit file dengan: nano .env"
        log_info "Setelah selesai, jalankan: ./scripts/setup.sh"
        exit 0
    else
        log_error "File .env.example tidak ditemukan!"
        exit 1
    fi
fi

# Load environment variables
log_info "Loading konfigurasi dari .env..."
set -a
source .env
set +a

# Validasi konfigurasi penting
log_info "Memvalidasi konfigurasi..."

ERRORS=0

if [[ "$POSTGRES_PASSWORD" == "CHANGE_THIS"* ]] || [[ "$POSTGRES_PASSWORD" == "your_secure_postgres_password_here" ]]; then
    log_error "POSTGRES_PASSWORD belum diubah! Silakan edit .env"
    ERRORS=$((ERRORS + 1))
fi

if [[ "$GITLAB_ROOT_PASSWORD" == "CHANGE_THIS"* ]] || [[ "$GITLAB_ROOT_PASSWORD" == "initial_root_password_change_this" ]]; then
    log_error "GITLAB_ROOT_PASSWORD belum diubah! Silakan edit .env"
    ERRORS=$((ERRORS + 1))
fi

if [[ "$GITLAB_DOMAIN" == "example.com" ]] || [[ "$GITLAB_HOSTNAME" == "example.com" ]]; then
    log_warning "GITLAB_DOMAIN masih menggunakan example.com"
    log_warning "Disarankan untuk mengganti dengan domain Anda"
fi

if [ $ERRORS -gt 0 ]; then
    log_error "Ada $ERRORS error dalam konfigurasi. Silakan edit .env"
    exit 1
fi

log_success "Validasi konfigurasi OK!"

# Cek Docker
log_info "Mengecek Docker..."
if ! command -v docker &> /dev/null; then
    log_error "Docker tidak terinstall!"
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    log_error "Docker Compose tidak terinstall!"
    exit 1
fi

log_success "Docker OK!"

# Membuat direktori data
log_info "Membuat direktori data..."

mkdir -p data/gitlab/config
mkdir -p data/gitlab/logs
mkdir -p data/gitlab/data
mkdir -p data/gitlab/backups
mkdir -p data/gitlab/ssl
mkdir -p data/postgres
mkdir -p data/redis

log_success "Direktori data dibuat!"

# Validasi docker-compose.yml
log_info "Memvalidasi docker-compose.yml..."
if ! docker-compose config --quiet 2>/dev/null; then
    log_error "docker-compose.yml tidak valid!"
    docker-compose config
    exit 1
fi
log_success "docker-compose.yml valid!"

# Tampilkan ringkasan
echo ""
echo "============================================"
echo "         RINGKASAN KONFIGURASI"
echo "============================================"
echo "Domain      : ${GITLAB_DOMAIN}"
echo "HTTP Port   : ${GITLAB_HTTP_PORT}"
echo "HTTPS Port  : ${GITLAB_HTTPS_PORT}"
echo "SSH Port    : ${GITLAB_SSH_PORT}"
echo "Timezone    : ${GITLAB_TIMEZONE}"
echo "============================================"
echo ""

# Konfirmasi
read -p "Lanjutkan deploy? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Deploy dibatalkan."
    exit 0
fi

# Deploy
log_info "Memulai deploy GitLab..."
docker-compose up -d

log_info "Menunggu container startup (60 detik)..."
sleep 60

# Fix socket permission
log_info "Memperbaiki socket permission..."

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

log_success "Socket permission diperbaiki!"

# Cek status
log_info "Mengecek status container..."
docker-compose ps

# Test koneksi
echo ""
log_info "Testing koneksi..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${GITLAB_HTTP_PORT}/ 2>/dev/null || echo "000")

if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "302" ]; then
    log_success "GitLab dapat diakses! (HTTP $HTTP_STATUS)"
else
    log_warning "GitLab mungkin masih dalam proses startup (HTTP $HTTP_STATUS)"
    log_info "Tunggu beberapa menit dan coba akses manual"
fi

# Tampilkan informasi akses
echo ""
echo "============================================"
echo "           GITLAB SIAP DIGUNAKAN!"
echo "============================================"
echo ""
echo "Akses GitLab:"
echo "  URL      : http://${GITLAB_DOMAIN}:${GITLAB_HTTP_PORT}"
echo "  Username : root"
echo ""
echo "Password root ada di:"
echo "  docker exec gitlab cat /etc/gitlab/initial_root_password"
echo ""
echo "Atau jika sudah diset di .env:"
echo "  Password : (sesuai GITLAB_ROOT_PASSWORD)"
echo ""
echo "============================================"
echo ""
log_success "Setup selesai!"
