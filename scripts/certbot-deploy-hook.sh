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

# Compose interpolates the whole file for every command, so it needs both env files:
# secrets in .env, image tags in versions.env (same invocation as scripts/deploy.sh).
compose() {
    docker compose --project-directory "$APP_DIR" -f "$APP_DIR/compose.prod.yaml" \
        --env-file "$APP_DIR/.env" --env-file "$APP_DIR/versions.env" "$@"
}

# Reload only if the gateway is running; on the very first issuance it may still be on plain HTTP.
# Query first, outside `if`: a failing command in an `if` condition does not trip `set -e`,
# so a broken compose call would silently skip the reload and still report success.
running="$(compose ps --status running --services)"
if printf '%s\n' "$running" | grep -qx gateway; then
    # nginx prints its "signal process started" notice to stderr, which certbot reports as
    # "error output". Failures still surface through the exit code (set -e).
    compose exec -T gateway nginx -s reload 2>&1
fi
