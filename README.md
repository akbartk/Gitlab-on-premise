# GitLab CE Docker Compose

Deploy GitLab Community Edition dengan Docker Compose - mudah, cepat, dan terpusat.

## Fitur

- **100% Gratis** - GitLab CE tanpa biaya lisensi
- **Konfigurasi Terpusat** - Semua kredensial di file `.env`
- **Auto Setup** - Script otomatis untuk instalasi
- **Production Ready** - Dengan health check, logging, dan backup
- **Easy Management** - Script untuk start/stop/backup/dll

## Requirements

| Minimum | Recommended |
|---------|-------------|
| 2 GB RAM | 4+ GB RAM |
| 2 CPU cores | 4+ CPU cores |
| 20 GB disk | 50+ GB SSD |

**Software:**
- Docker 20.10+
- Docker Compose 2.0+

## Quick Start (5 Menit)

```bash
# 1. Clone repository
git clone <repo-url> gitlab-docker
cd gitlab-docker

# 2. Buat file konfigurasi
cp .env.example .env
nano .env  # Edit domain dan password

# 3. Jalankan setup otomatis
chmod +x scripts/*.sh
./scripts/setup.sh
```

Selesai! Akses GitLab di `http://your-domain:8880`

## Struktur Folder

```
.
├── .env                    # Konfigurasi aktif (JANGAN commit!)
├── .env.example            # Template konfigurasi
├── docker-compose.yml      # Konfigurasi Docker Compose
├── README.md               # Dokumentasi ini
├── CHANGELOG.md            # Log perubahan
├── data/                   # Data persistent
│   ├── gitlab/            # Data GitLab
│   ├── postgres/          # Database PostgreSQL
│   └── redis/             # Cache Redis
└── scripts/               # Script helper
    ├── setup.sh           # Setup otomatis
    ├── manage.sh          # Manajemen GitLab
    ├── fix-socket-permission.sh
    └── gitlab-entrypoint.sh
```

## Konfigurasi

### File .env

Semua konfigurasi ada di file `.env`. Copy dari template:

```bash
cp .env.example .env
```

### Variabel Penting

| Variabel | Keterangan | Contoh |
|----------|------------|--------|
| `GITLAB_DOMAIN` | Domain GitLab | `gitlab.mycompany.com` |
| `GITLAB_HTTP_PORT` | Port HTTP | `8880` |
| `GITLAB_SSH_PORT` | Port SSH | `8822` |
| `POSTGRES_PASSWORD` | Password database | (password kuat) |
| `GITLAB_ROOT_PASSWORD` | Password root awal | (password kuat) |

### Lihat semua variabel di `.env.example`

## Penggunaan

### Setup Awal

```bash
# Setup otomatis (termasuk fix socket)
./scripts/setup.sh
```

### Mengelola GitLab

```bash
# Lihat semua command
./scripts/manage.sh help

# Start/Stop/Restart
./scripts/manage.sh start
./scripts/manage.sh stop
./scripts/manage.sh restart

# Cek status
./scripts/manage.sh status

# Lihat log
./scripts/manage.sh logs
./scripts/manage.sh logs postgres

# Fix socket permission (jika 502 error)
./scripts/manage.sh fix

# Backup
./scripts/manage.sh backup

# Lihat/reset password root
./scripts/manage.sh password

# Masuk shell container
./scripts/manage.sh shell
```

### Manual (tanpa script)

```bash
# Start
docker-compose up -d

# Stop
docker-compose down

# Lihat log
docker-compose logs -f gitlab

# Fix socket permission
docker exec gitlab chmod 777 /var/opt/gitlab/gitlab-workhorse/sockets/socket
docker exec gitlab chmod 777 /var/opt/gitlab/gitlab-rails/sockets/gitlab.socket
```

## Akses GitLab

Setelah setup selesai:

1. Buka browser: `http://your-domain:8880`
2. Login dengan:
   - **Username**: `root`
   - **Password**: Lihat dengan `./scripts/manage.sh password`

### Password Root

```bash
# Lihat password yang digenerate
docker exec gitlab cat /etc/gitlab/initial_root_password

# Reset password
docker exec -it gitlab gitlab-rake "gitlab:password:reset[root]"
```

## Troubleshooting

### HTTP 502 Bad Gateway

**Penyebab**: Nginx tidak bisa connect ke socket GitLab

**Solusi**:
```bash
./scripts/manage.sh fix
```

### Container Unhealthy

**Penyebab**: GitLab butuh waktu 5-10 menit untuk startup pertama

**Solusi**: Tunggu beberapa menit, lalu:
```bash
./scripts/manage.sh status
./scripts/manage.sh fix
```

### Lupa Password Root

```bash
./scripts/manage.sh password
# atau reset:
docker exec -it gitlab gitlab-rake "gitlab:password:reset[root]"
```

### Reset Semua (Hati-hati!)

```bash
./scripts/manage.sh clean
```

## Port yang Digunakan

| Port | Service | Keterangan |
|------|---------|------------|
| 8880 | HTTP | Web interface |
| 8843 | HTTPS | Web interface (SSL) |
| 8822 | SSH | Git operations |

Ganti port di file `.env` jika ada konflik.

## Backup & Restore

### Backup

```bash
# Manual
./scripts/manage.sh backup

# Atau cron job (setiap hari jam 2 pagi)
# 0 2 * * * /path/to/gitlab/scripts/manage.sh backup
```

Backup disimpan di: `data/gitlab/backups/`

### Restore

```bash
# List backup
ls data/gitlab/backups/

# Restore
docker exec gitlab gitlab-backup restore BACKUP=timestamp_filename
```

## SSL/HTTPS

1. Siapkan certificate:
```bash
# Let's Encrypt
certbot certonly --standalone -d gitlab.yourdomain.com

# Copy ke folder SSL
cp /etc/letsencrypt/live/gitlab.yourdomain.com/fullchain.pem data/gitlab/ssl/
cp /etc/letsencrypt/live/gitlab.yourdomain.com/privkey.pem data/gitlab/ssl/
```

2. Update `.env`:
```env
GITLAB_PROTOCOL=https
GITLAB_SSL_ENABLE=true
GITLAB_SSL_CERTIFICATE=/etc/gitlab/ssl/fullchain.pem
GITLAB_SSL_CERTIFICATE_KEY=/etc/gitlab/ssl/privkey.pem
```

3. Restart:
```bash
./scripts/manage.sh restart
```

## Upgrade

```bash
# Pull image terbaru dan restart
./scripts/manage.sh update
```

## Keamanan

1. **Ganti semua password** di `.env` sebelum deploy
2. **Jangan commit** file `.env` ke repository
3. **Enable 2FA** untuk user admin
4. **Setup firewall** untuk membatasi akses port
5. **Regular backups** untuk mencegah kehilangan data

## Contributing

1. Fork repository
2. Buat branch fitur
3. Commit perubahan
4. Push ke branch
5. Buat Pull Request

## License

MIT License - bebas digunakan untuk keperluan apapun.

## Support

Jika mengalami masalah:
1. Baca bagian [Troubleshooting](#troubleshooting)
2. Cek log: `./scripts/manage.sh logs`
3. Buka issue di repository
