#!/bin/bash
# ============================================
# GitLab Socket Permission Fix Script
# ============================================
# Script ini memperbaiki permission socket GitLab
# untuk mengatasi masalah nginx tidak bisa connect
#
# CATATAN: Menggunakan chmod 777 karena ACL dari host
# filesystem tidak bisa diatasi dengan usermod + 770
# ============================================

GITLAB_CONTAINER="${GITLAB_CONTAINER:-gitlab}"

echo "Memperbaiki socket permission..."

# Fix directory permissions
docker exec $GITLAB_CONTAINER chmod 755 /var/opt/gitlab/gitlab-workhorse/ 2>/dev/null
docker exec $GITLAB_CONTAINER chmod 755 /var/opt/gitlab/gitlab-workhorse/sockets/ 2>/dev/null
docker exec $GITLAB_CONTAINER chmod 755 /var/opt/gitlab/gitlab-rails/ 2>/dev/null
docker exec $GITLAB_CONTAINER chmod 755 /var/opt/gitlab/gitlab-rails/sockets/ 2>/dev/null

# Fix socket permissions (777 karena ACL dari host filesystem)
docker exec $GITLAB_CONTAINER chmod 777 /var/opt/gitlab/gitlab-workhorse/sockets/socket 2>/dev/null
docker exec $GITLAB_CONTAINER chmod 777 /var/opt/gitlab/gitlab-rails/sockets/gitlab.socket 2>/dev/null

echo "  socket: chmod 777"

# Restart gitlab-workhorse
echo "Restarting gitlab-workhorse..."
docker exec $GITLAB_CONTAINER gitlab-ctl restart gitlab-workhorse 2>/dev/null
sleep 5

# Fix socket permission lagi setelah restart
docker exec $GITLAB_CONTAINER chmod 777 /var/opt/gitlab/gitlab-workhorse/sockets/socket 2>/dev/null
docker exec $GITLAB_CONTAINER chmod 777 /var/opt/gitlab/gitlab-rails/sockets/gitlab.socket 2>/dev/null

echo "Socket permission diperbaiki!"

# Test koneksi
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${GITLAB_HTTP_PORT:-8880}/ 2>/dev/null)
echo "HTTP Status: $HTTP_STATUS"

if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "302" ]; then
    echo "GitLab dapat diakses!"
else
    echo "GitLab masih bermasalah (HTTP $HTTP_STATUS)"
fi
