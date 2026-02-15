#!/bin/bash
# ============================================
# GitLab Custom Entrypoint Wrapper
# ============================================
# Wrapper untuk /assets/wrapper yang juga memperbaiki
# socket permission setelah startup
# ============================================

# Jalankan GitLab entrypoint di background
/assets/wrapper &

# Tunggu sockets tersedia
echo "⏳ Menunggu socket GitLab tersedia..."
MAX_WAIT=120
WAITED=0

while [ $WAITED -lt $MAX_WAIT ]; do
    if [ -S /var/opt/gitlab/gitlab-workhorse/sockets/socket ]; then
        echo "✅ Socket workhorse tersedia"

        # Fix permissions
        chmod 755 /var/opt/gitlab/gitlab-workhorse/ 2>/dev/null
        chmod 755 /var/opt/gitlab/gitlab-workhorse/sockets/ 2>/dev/null
        chmod 777 /var/opt/gitlab/gitlab-workhorse/sockets/socket 2>/dev/null

        chmod 755 /var/opt/gitlab/gitlab-rails/ 2>/dev/null
        chmod 755 /var/opt/gitlab/gitlab-rails/sockets/ 2>/dev/null
        chmod 777 /var/opt/gitlab/gitlab-rails/sockets/gitlab.socket 2>/dev/null

        echo "✅ Socket permission diperbaiki!"
        break
    fi

    sleep 2
    WAITED=$((WAITED + 2))
    echo "   Menunggu... ($WAITED detik)"
done

if [ $WAITED -ge $MAX_WAIT ]; then
    echo "⚠️ Timeout menunggu socket (setelah ${MAX_WAIT} detik)"
fi

# Keep container running - forward ke GitLab process
wait
