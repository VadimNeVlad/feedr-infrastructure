#!/usr/bin/env bash
# Deploys one application image to production and rolls back if it does not come up healthy.
#
# Called by GitHub Actions over SSH as the `deploy` user. The deploy key is pinned to this
# script in ~deploy/.ssh/authorized_keys:
#   command="/opt/feedr/scripts/deploy.sh",restrict ssh-ed25519 AAAA... github-actions-deploy
# so the key can never open a shell; the client's arguments arrive in SSH_ORIGINAL_COMMAND:
#   ssh deploy@<host> backend sha-abc1234
# An administrator on the server can run it directly instead:
#   sudo -u deploy /opt/feedr/scripts/deploy.sh frontend sha-abc1234
set -euo pipefail

APP_DIR=/opt/feedr
VERSIONS_FILE="$APP_DIR/versions.env"
LOCK_FILE="$APP_DIR/.deploy.lock"
PUBLIC_URL="${PUBLIC_URL:-https://devmakeops.xyz}"

log() {
    printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"
    # Audit trail on the server as well: journalctl -t feedr-deploy
    logger -t feedr-deploy -- "$*" 2>/dev/null || true
}

die() {
    log "ERROR: $*"
    exit 1
}

# Image tags live in versions.env (no secrets, written only by this script);
# secrets stay in .env. Later --env-file wins, so the tag in versions.env is authoritative.
compose() {
    docker compose --project-directory "$APP_DIR" -f "$APP_DIR/compose.prod.yaml" \
        --env-file "$APP_DIR/.env" --env-file "$VERSIONS_FILE" "$@"
}

# --- Input: from the forced SSH command, or from the command line --------------------------
if [[ -n "${SSH_ORIGINAL_COMMAND:-}" ]]; then
    read -r service tag extra <<<"$SSH_ORIGINAL_COMMAND"
else
    service="${1:-}" tag="${2:-}" extra="${3:-}"
fi

usage="usage: deploy.sh <backend|frontend> <sha-xxxxxxx>"
[[ -z "${extra:-}" ]] || die "unexpected extra arguments; $usage"

# Strict allowlist: nothing from the client reaches a shell or a file unchecked.
case "${service:-}" in
    backend)  tag_var=BACKEND_TAG;  images=(migrate backend) ;;
    frontend) tag_var=FRONTEND_TAG; images=(frontend) ;;
    *) die "unknown service '${service:-}'; $usage" ;;
esac
[[ "${tag:-}" =~ ^sha-[0-9a-f]{7,40}$ ]] || die "invalid tag '${tag:-}'; $usage"

# --- One deploy at a time (GitHub concurrency is the first line, this is the second) -------
exec 9>"$LOCK_FILE"
flock -w 600 9 || die "another deploy is still running"

[[ -f "$VERSIONS_FILE" ]] || die "$VERSIONS_FILE is missing (create it with BACKEND_TAG= and FRONTEND_TAG=)"

get_tag() {
    sed -n "s/^$1=//p" "$VERSIONS_FILE" | tail -n 1
}

# Atomic update: write a temp file in the same directory, then rename over the original.
set_tag() {
    local tmp
    tmp="$(mktemp "$VERSIONS_FILE.XXXXXX")" || return 1
    grep -v "^$1=" "$VERSIONS_FILE" >"$tmp" || true
    printf '%s=%s\n' "$1" "$2" >>"$tmp"
    chmod 644 "$tmp"
    mv "$tmp" "$VERSIONS_FILE"
}

smoke_test() {
    local path
    for path in /api/health /; do
        curl -fsS -o /dev/null --max-time 10 --retry 5 --retry-delay 3 --retry-all-errors \
            "$PUBLIC_URL$path" || { log "smoke test failed: $PUBLIC_URL$path"; return 1; }
    done
}

# rollout <tag> <run_migrations: yes|no>
# Commands are checked explicitly: `set -e` does not apply inside a function called from `if`.
rollout() {
    set_tag "$tag_var" "$1" || return 1
    compose pull --quiet "${images[@]}" || return 1
    if [[ "$service" == backend && "$2" == yes ]]; then
        log "running migrations"
        compose run --rm --no-deps migrate || return 1
    fi
    compose up -d --no-deps --wait --wait-timeout 180 "$service" || return 1
    smoke_test
}

# --- Deploy -------------------------------------------------------------------------------
previous="$(get_tag "$tag_var")"

if [[ "$previous" == "$tag" ]]; then
    log "$service is already at $tag, nothing to do"
    exit 0
fi

log "deploying $service $tag (previous: ${previous:-none})"
if rollout "$tag" yes; then
    log "deployed $service $tag"
    exit 0
fi

log "deploy of $service $tag failed"
[[ -n "$previous" ]] || die "no previous tag to roll back to"

# Migrations are not reverted: the database stays on the new schema, so migrations must be
# backward compatible (expand/contract). The old image is still in the local cache.
log "rolling back $service to $previous"
if rollout "$previous" no; then
    log "rolled back $service to $previous"
else
    log "ROLLBACK FAILED: $service is down, manual intervention needed"
fi
exit 1
