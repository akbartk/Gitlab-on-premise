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

---

## setup.sh - One-Click Setup

`setup.sh` adalah script utama untuk deploy GitLab. Script ini melakukan semuanya secara otomatis.

### Kapan Menggunakan setup.sh?

| Kondisi | Gunakan setup.sh? |
|---------|-------------------|
| Instalasi pertama kali | Ya |
| Setelah edit .env | Ya |
| Setelah server reboot | Tidak (gunakan `./scripts/manage.sh start`) |
| Untuk start/stop harian | Tidak (gunakan `./scripts/manage.sh`) |
| Untuk fix socket error | Tidak (gunakan `./scripts/manage.sh fix`) |

### Apa yang Dilakukan setup.sh?

```
1. Cek .env (buat dari template jika belum ada)
2. Validasi konfigurasi (password, domain)
3. Cek Docker & Docker Compose
4. Buat direktori data
5. Validasi docker-compose.yml
6. Tampilkan ringkasan konfigurasi
7. Konfirmasi sebelum deploy
8. Deploy dengan docker-compose up -d
9. Tunggu container startup (60 detik)
10. Fix socket permission + restart workhorse
11. Test koneksi HTTP
12. Tampilkan informasi akses
```

### Cara Penggunaan

#### Langkah 1: Clone & Persiapan

```bash
# Clone repository
git clone git@github.com:akbartk/Gitlab-on-premise.git
cd Gitlab-on-premise

# Berikan permission execute
chmod +x setup.sh
```

#### Langkah 2: Generate .env

```bash
# Jalankan setup.sh pertama kali
./setup.sh
```

Output:
```
============================================
   GitLab CE Docker Compose Auto Setup
============================================

[WARNING] File .env tidak ditemukan!
[INFO] Membuat .env dari .env.example...
[WARNING] SILAKAN EDIT FILE .env SEBELUM MELANJUTKAN!
[WARNING] Ganti semua nilai CHANGE_THIS_* dengan nilai yang sesuai.

[INFO] Edit file dengan: nano .env
[INFO] Setelah selesai, jalankan: ./setup.sh
```

#### Langkah 3: Edit .env

```bash
nano .env
```

**WAJIB diubah:**
```env
# Ganti dengan domain Anda
GITLAB_HOSTNAME=gitlab.yourcompany.com
GITLAB_DOMAIN=gitlab.yourcompany.com

# Ganti dengan password yang kuat
POSTGRES_PASSWORD=YourStrongPassword123!
GITLAB_ROOT_PASSWORD=YourRootPassword123!
```

#### Langkah 4: Deploy

```bash
# Jalankan setup.sh lagi
./setup.sh
```

Output:
```
============================================
   GitLab CE Docker Compose Auto Setup
============================================

[INFO] Loading konfigurasi dari .env...
[INFO] Memvalidasi konfigurasi...
[SUCCESS] Validasi konfigurasi OK!
[INFO] Mengecek Docker...
[SUCCESS] Docker OK!
[INFO] Membuat direktori data...
[SUCCESS] Direktori data dibuat!
[INFO] Memvalidasi docker-compose.yml...
[SUCCESS] docker-compose.yml valid!

============================================
         RINGKASAN KONFIGURASI
============================================
Domain      : gitlab.yourcompany.com
HTTP Port   : 8880
HTTPS Port  : 8843
SSH Port    : 8822
Timezone    : Asia/Jakarta
============================================

Lanjutkan deploy? (y/n): y

[INFO] Memulai deploy GitLab...
[INFO] Menunggu container startup (60 detik)...
[INFO] Memperbaiki socket permission...
[INFO] Restarting gitlab-workhorse...
[SUCCESS] Socket permission diperbaiki!
[INFO] Mengecek status container...
[SUCCESS] GitLab dapat diakses! (HTTP 302)

============================================
           GITLAB SIAP DIGUNAKAN!
============================================

Akses GitLab:
  URL      : http://gitlab.yourcompany.com:8880
  Username : root

Password root ada di:
  docker exec gitlab cat /etc/gitlab/initial_root_password

============================================
[SUCCESS] Setup selesai!
```

---

## Struktur Folder

```
.
├── setup.sh                # One-Click Setup (START HERE!)
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
    ├── manage.sh          # Manajemen GitLab (start/stop/logs)
    ├── fix-socket-permission.sh
    └── gitlab-entrypoint.sh
```

---

## Konfigurasi

### File .env

Semua konfigurasi ada di file `.env`. Copy dari template:

```bash
cp .env.example .env
```

### Variabel Penting

| Variabel | Keterangan | Contemplo |
|----------|------------|--------|
| `GITLAB_DOMAIN` | Domain GitLab | `gitlab.mycompany.com` |
| `GITLAB_HTTP_PORT` | Port HTTP | `8880` |
| `GITLAB_SSH_PORT` | Port SSH | `8822` |
| `POSTGRES_PASSWORD` | Password database | (password kuat) |
| `GITLAB_ROOT_PASSWORD` | Password root awal | (password kuat) |

### Lihat semua variabel di `.env.example`

---

## Penggunaan Sehari-hari

Gunakan `scripts/manage.sh` untuk operasi sehari-hari:

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

---

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

---

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

---

## Port yang Digunakan

| Port | Service | Keterangan |
|------|---------|------------|
| 8880 | HTTP | Web interface |
| 8843 | HTTPS | Web interface (SSL) |
| 8822 | SSH | Git operations |

Ganti port di file `.env` jika ada konflik.

---

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

---

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

---

## Upgrade

```bash
# Pull image terbaru dan restart
./scripts/manage.sh update
```

---

## Keamanan

1. **Ganti semua password** di `.env` sebelum deploy
2. **Jangan commit** file `.env` ke repository
3. **Enable 2FA** untuk user admin
4. **Setup firewall** untuk membatasi akses port
5. **Regular backups** untuk mencegah kehilangan data

---

## License

MIT License - bebas digunakan untuk keperluan apapun.

## Support

Jika mengalami masalah:
1. Baca bagian [Troubleshooting](#troubleshooting)
2. Cek log: `./scripts/manage.sh logs`
3. Buka issue di repository
