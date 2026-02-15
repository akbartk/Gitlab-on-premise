#!/bin/bash
# ============================================
# GitLab Custom Entrypoint with Socket Fix
# ============================================
# Script ini berjalan otomatis setiap container start
# Melakukan:
#   1. Tambahkan gitlab-www ke group git (usermod)
#   2. Jalankan GitLab normal (/assets/wrapper)
#   3. Fix socket permission (770)
# ============================================

echo "[ENTRYPOINT] Starting GitLab with socket permission fix..."

# ============================================
# STEP 1: Fix Group Membership
# ============================================
# Tambahkan user gitlab-www ke group git
# Ini memungkinkan nginx (gitlab-www) mengakses socket dengan chmod 770
echo "[ENTRYPOINT] Adding gitlab-www to git group..."
if usermod -aG git gitlab-www 2>/dev/null; then
    echo "[ENTRYPOINT] Successfully added gitlab-www to git group"
else
    echo "[ENTRYPOINT] WARNING: usermod failed, will use chmod 777 fallback"
fi

# ============================================
# STEP 2: Start GitLab (background)
# ============================================
echo "[ENTRYPOINT] Starting GitLab services..."
/assets/wrapper &

# ============================================
# STEP 3: Wait for sockets
# ============================================
echo "[ENTRYPOINT] Waiting for sockets to be created..."
MAX_WAIT=120
WAITED=0

while [ $WAITED -lt $MAX_WAIT ]; do
    if [ -S /var/opt/gitlab/gitlab-workhorse/sockets/socket ]; then
        echo "[ENTRYPOINT] Sockets ready after ${WAITED}s"
        break
    fi
    sleep 2
    WAITED=$((WAITED + 2))
done

if [ $WAITED -ge $MAX_WAIT ]; then
    echo "[ENTRYPOINT] WARNING: Timeout waiting for sockets (${MAX_WAIT}s)"
fi

# ============================================
# STEP 4: Fix Socket Permissions
# ============================================
echo "[ENTRYPOINT] Fixing socket permissions..."

# Fix directory permissions
chmod 755 /var/opt/gitlab/gitlab-workhorse/ 2>/dev/null || true
chmod 755 /var/opt/gitlab/gitlab-workhorse/sockets/ 2>/dev/null || true
chmod 755 /var/opt/gitlab/gitlab-rails/ 2>/dev/null || true
chmod 755 /var/opt/gitlab/gitlab-rails/sockets/ 2>/dev/null || true

# Try chmod 770 first (if usermod succeeded)
if chmod 770 /var/opt/gitlab/gitlab-workhorse/sockets/socket 2>/dev/null; then
    echo "[ENTRYPOINT] workhorse socket: chmod 770 (secure)"
else
    # Fallback to 777 if 770 fails
    chmod 777 /var/opt/gitlab/gitlab-workhorse/sockets/socket 2>/dev/null || true
    echo "[ENTRYPOINT] workhorse socket: chmod 777 (fallback)"
fi

if chmod 770 /var/opt/gitlab/gitlab-rails/sockets/gitlab.socket 2>/dev/null; then
    echo "[ENTRYPOINT] rails socket: chmod 770 (secure)"
else
    # Fallback to 777 if 770 fails
    chmod 777 /var/opt/gitlab/gitlab-rails/sockets/gitlab.socket 2>/dev/null || true
    echo "[ENTRYPOINT] rails socket: chmod 777 (fallback)"
fi

# ============================================
# STEP 5: Restart gitlab-workhorse
# ============================================
# Restart workhorse so it creates socket with correct group
echo "[ENTRYPOINT] Restarting gitlab-workhorse..."
gitlab-ctl restart gitlab-workhorse 2>/dev/null || true
sleep 5

# Fix socket permission again after restart
chmod 770 /var/opt/gitlab/gitlab-workhorse/sockets/socket 2>/dev/null || \
chmod 777 /var/opt/gitlab/gitlab-workhorse/sockets/socket 2>/dev/null || true
chmod 770 /var/opt/gitlab/gitlab-rails/sockets/gitlab.socket 2>/dev/null || \
chmod 777 /var/opt/gitlab/gitlab-rails/sockets/gitlab.socket 2>/dev/null || true

echo "[ENTRYPOINT] Socket permissions fixed!"
echo "[ENTRYPOINT] GitLab is ready!"

# Keep container running
wait
