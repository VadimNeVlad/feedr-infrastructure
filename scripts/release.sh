#!/usr/bin/env bash
# Starts a production release through GitHub Actions (.github/workflows/deploy.yml)
# and follows it until it finishes. Usually called via `make release`.
#
# Usage: scripts/release.sh [-y] <backend> <frontend>
#   each argument: latest | sha-xxxxxxx | - (skip this service)
#   scripts/release.sh latest latest       weekly release, both services
#   scripts/release.sh - latest            hotfix, frontend only
#   scripts/release.sh sha-29d0092 -       rollback backend to a known tag
#   -y  skip the confirmation prompt (for automation; humans should confirm)
#
# Requires the GitHub CLI, logged in: gh auth login
set -euo pipefail

REPO="VadimNeVlad/feedr-infrastructure"
WORKFLOW="deploy.yml"

usage() {
    echo "usage: $0 [-y] <backend> <frontend>   (each: latest | sha-xxxxxxx | - to skip)" >&2
    exit 2
}

assume_yes=false
if [[ "${1:-}" == "-y" ]]; then
    assume_yes=true
    shift
fi
[[ $# -eq 2 ]] || usage

# "-" means "do not touch this service"; the workflow expects an empty value for that.
normalize() {
    case "$1" in
        "") echo "missing value for a service: pass - to skip it explicitly" >&2; usage ;;
        -) echo "" ;;
        latest) echo latest ;;
        *) [[ "$1" =~ ^sha-[0-9a-f]{7,40}$ ]] || { echo "invalid tag '$1'" >&2; usage; }
           echo "$1" ;;
    esac
}
backend="$(normalize "$1")"
frontend="$(normalize "$2")"
[[ -n "$backend" || -n "$frontend" ]] || { echo "nothing to release: both services are '-'" >&2; usage; }

command -v gh >/dev/null || { echo "GitHub CLI (gh) is not installed: https://cli.github.com" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "gh is not logged in: run 'gh auth login'" >&2; exit 1; }

# Preview what `latest` means right now (the workflow resolves it again when it runs).
preview() {  # preview <value> <app repo>
    local sha
    if [[ "$1" == latest ]]; then
        sha="$(gh run list -R "VadimNeVlad/$2" --workflow ci.yml --branch master \
            --event push --status success --limit 1 --json headSha --jq '.[0].headSha' 2>/dev/null || true)"
        echo "latest (now sha-${sha:0:7})"
    else
        echo "${1:-skip}"
    fi
}

echo "PRODUCTION release (https://devmakeops.xyz)"
echo "  backend:  $(preview "$backend" feeds-backend)"
echo "  frontend: $(preview "$frontend" feedR)"
if [[ "$assume_yes" != true ]]; then
    read -r -p "Continue? [y/N] " answer
    [[ "$answer" == [yY] ]] || { echo "aborted"; exit 1; }
fi

# A minute of slack covers a local clock that runs ahead of GitHub's.
started_at="$(date -u -d '1 minute ago' +%Y-%m-%dT%H:%M:%SZ)"
gh workflow run "$WORKFLOW" -R "$REPO" -f backend_tag="$backend" -f frontend_tag="$frontend"

# `gh workflow run` does not return the run id: find the run this user just started.
me="$(gh api user --jq .login)"
run_id=""
for _ in $(seq 1 15); do
    run_id="$(gh run list -R "$REPO" --workflow "$WORKFLOW" --event workflow_dispatch --user "$me" \
        --limit 5 --json databaseId,createdAt \
        --jq "[.[] | select(.createdAt >= \"$started_at\")] | last | .databaseId // empty")"
    [[ -n "$run_id" ]] && break
    sleep 2
done
[[ -n "$run_id" ]] || { echo "release started, but the run was not found; check https://github.com/$REPO/actions" >&2; exit 1; }

echo "https://github.com/$REPO/actions/runs/$run_id"
# --exit-status: this script fails if the deploy fails, so the operator cannot miss it.
gh run watch "$run_id" -R "$REPO" --exit-status
