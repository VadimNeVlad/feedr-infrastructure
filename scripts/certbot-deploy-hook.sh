#!/bin/sh
# certbot deploy hook: runs as root after every successful issuance or renewal.
#
# The gateway runs as uid 101 (nginx-unprivileged) and cannot read /etc/letsencrypt
# (private keys there are root-only). Copy the current certificate into the app's
# certs/ directory owned by 101, then reload nginx without dropping connections.
#
# Install (as root-owned copy, never a symlink into the repo — the repo is writable
# by a non-root user, and this script runs as root):
#   sudo install -m 755 -o root -g root scripts/certbot-deploy-hook.sh /usr/local/sbin/feedr-certbot-deploy-hook
set -eu

APP_DIR=/opt/feedr
DEST="$APP_DIR/certs"
NGINX_UID=101

# certbot sets RENEWED_LINEAGE to /etc/letsencrypt/live/<cert-name>.
: "${RENEWED_LINEAGE:?must be run by certbot (RENEWED_LINEAGE is not set)}"

install -m 644 -o "$NGINX_UID" -g "$NGINX_UID" "$RENEWED_LINEAGE/fullchain.pem" "$DEST/fullchain.pem"
install -m 600 -o "$NGINX_UID" -g "$NGINX_UID" "$RENEWED_LINEAGE/privkey.pem" "$DEST/privkey.pem"

# Reload only if the gateway is running; on the very first issuance it may still be on plain HTTP.
if docker compose -f "$APP_DIR/compose.prod.yaml" ps --status running --services | grep -qx gateway; then
    # nginx prints its "signal process started" notice to stderr, which certbot reports as
    # "error output". Failures still surface through the exit code (set -e).
    docker compose -f "$APP_DIR/compose.prod.yaml" exec -T gateway nginx -s reload 2>&1
fi
