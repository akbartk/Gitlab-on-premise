# Changelog

Semua perubahan penting pada proyek ini akan didokumentasikan di file ini.

---

## [2026-02-15] - Dokumentasi & Script Otomatis

### Ditambahkan
- **README.md** - Dokumentasi lengkap untuk pengguna baru
- **scripts/setup.sh** - Script setup otomatis dengan validasi
- **scripts/manage.sh** - Script manajemen GitLab (start/stop/logs/backup/dll)

### Fitur Script setup.sh
- Validasi konfigurasi sebelum deploy
- Cek password yang belum diubah
- Pembuatan direktori data otomatis
- Deploy dengan docker-compose
- Auto-fix socket permission setelah startup
- Tampilkan informasi akses setelah selesai

### Fitur Script manage.sh
- `start` - Start containers
- `stop` - Stop containers
- `restart` - Restart dengan auto-fix
- `status` - Cek status container dan HTTP
- `logs` - Lihat log (semua atau per service)
- `fix` - Fix socket permission
- `backup` - Buat backup GitLab
- `password` - Lihat/reset password root
- `shell` - Masuk ke container shell
- `reconfigure` - Reconfigure GitLab
- `update` - Update ke image terbaru
- `clean` - Hapus semua data (dangerous)

### Diubah
- **.env.example** - Diperbarui dengan komentar yang lebih jelas
- Password template menggunakan `CHANGE_THIS_*` untuk mudah diidentifikasi

### File yang Dihapus (Cleanup)
- docker-compose-ce.yml, docker-compose.production.yml
- README.md, FILE-INDEX.md, CE-UPDATE-SUMMARY.md, dll
- gitlab-helper.sh, gitlab-monitor.sh, setup-gitlab-ce.sh, setup-gitlab.sh

---

## [2026-02-15] - Bug Fix: Socket Permission

### Masalah
- GitLab container menunjukkan status `unhealthy`
- HTTP 502 Bad Gateway error
- Nginx tidak bisa connect ke gitlab-workhorse socket (Permission denied)

### Penyebab
- Socket permission tidak mengizinkan nginx (user gitlab-www) untuk mengakses
- Socket owner: `git:git` (UID 998)
- Nginx worker: `gitlab-www` (UID 999)
- Permission socket: 775 dengan ACL yang membatasi akses

### Solusi
1. **Manual fix** (langsung):
   ```bash
   docker exec gitlab chmod 755 /var/opt/gitlab/gitlab-workhorse/
   docker exec gitlab chmod 755 /var/opt/gitlab/gitlab-workhorse/sockets/
   docker exec gitlab chmod 777 /var/opt/gitlab/gitlab-workhorse/sockets/socket
   docker exec gitlab chmod 755 /var/opt/gitlab/gitlab-rails/
   docker exec gitlab chmod 755 /var/opt/gitlab/gitlab-rails/sockets/
   docker exec gitlab chmod 777 /var/opt/gitlab/gitlab-rails/sockets/gitlab.socket
   ```

2. **Automated fix** (via docker-compose):
   - Menambahkan `post_start` hook di docker-compose.yml
   - Script `scripts/fix-socket-permission.sh` untuk manual fix
   - Script `scripts/gitlab-entrypoint.sh` untuk custom entrypoint

### File Baru
- `scripts/fix-socket-permission.sh` - Script untuk fix permission manual
- `scripts/gitlab-entrypoint.sh` - Custom entrypoint wrapper

### Perubahan docker-compose.yml
- Menambahkan `post_start` hook untuk auto-fix socket permission
- Mount custom entrypoint script

### Hasil
- ✅ Semua container status: **healthy**
- ✅ HTTP response: **302** (redirect ke login page)
- ✅ GitLab dapat diakses normal

---

## [2026-02-15] - Pemusatan Kredensial ke .env

### Ditambahkan
- **Pemusatan konfigurasi**: Semua kredensial dan konfigurasi sekarang terpusat di file `.env`
- **Port mapping ke .env**: HTTP_PORT, HTTPS_PORT, SSH_PORT dapat dikustomisasi
- **Docker image versions**: Versi image (GitLab, PostgreSQL, Redis) dapat dikelola via .env
- **Logging configuration**: Driver dan rotasi log dapat dikonfigurasi
- **SSL configuration**: Path certificate dapat diubah tanpa edit docker-compose.yml
- **Health check configuration**: Interval, timeout, retries dapat dikustomisasi
- **Redis max memory policy**: Policy eviction dapat dikonfigurasi

### Diubah
- **docker-compose.yml**: Sekarang menggunakan variabel dari .env dengan default values
- **.env.example**: Diperbarui dengan semua variabel yang diperlukan, dikelompokkan per kategori
- **Removed `version` attribute**: Dihapus karena obsolete di Docker Compose terbaru

### Daftar Variabel .env

| Kategori | Variabel | Keterangan |
|----------|----------|------------|
| **Host & Domain** | `GITLAB_HOSTNAME`, `GITLAB_DOMAIN`, `GITLAB_PROTOCOL` | Konfigurasi domain |
| **Port Mapping** | `GITLAB_HTTP_PORT`, `GITLAB_HTTPS_PORT`, `GITLAB_SSH_PORT`, `GITLAB_SHELL_SSH_PORT` | Port eksternal |
| **Database** | `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` | Kredensial PostgreSQL |
| **Redis** | `REDIS_MAX_MEMORY`, `REDIS_MAX_MEMORY_POLICY` | Konfigurasi cache |
| **GitLab** | `GITLAB_TIMEZONE`, `GITLAB_ROOT_PASSWORD`, `GITLAB_BACKUP_KEEP_TIME` | Settings GitLab |
| **SSL** | `GITLAB_SSL_ENABLE`, `GITLAB_SSL_CERTIFICATE`, `GITLAB_SSL_CERTIFICATE_KEY` | Konfigurasi SSL |
| **Performance** | `PUMA_WORKER_PROCESSES`, `PUMA_WORKER_TIMEOUT`, `POSTGRESQL_SHARED_BUFFERS`, `POSTGRESQL_MAX_WORKER_PROCESSES` | Tuning |
| **Docker Images** | `GITLAB_IMAGE_TAG`, `POSTGRES_IMAGE_TAG`, `REDIS_IMAGE_TAG` | Versi container |
| **Logging** | `LOG_DRIVER`, `LOG_MAX_SIZE`, `LOG_MAX_FILE` | Audit trail |
| **SMTP** | `GITLAB_SMTP_*` | Konfigurasi email (optional) |
| **Health Check** | `HEALTH_CHECK_*` | Monitoring configuration |

### Cara Penggunaan

```bash
# 1. Copy template .env
cp .env.example .env

# 2. Edit sesuai kebutuhan
nano .env

# 3. Validasi konfigurasi
docker-compose config

# 4. Jalankan
docker-compose up -d
```

### Keuntungan
- **Akuntabilitas**: Semua kredensial terpusat, mudah diaudit
- **Keamanan**: Password tidak hard-code di docker-compose.yml
- **Fleksibilitas**: Mudah ganti konfigurasi tanpa edit compose file
- **Version Control**: .env bisa di-exclude dari git, .env.example sebagai template
