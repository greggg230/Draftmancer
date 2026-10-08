#!/usr/bin/env bash
# Redeploys the pushed branch to the Hetzner host. Run from your machine:
#   deploy/hetzner/deploy.sh [root@HOST]
set -euo pipefail
HOST="${1:-${DRAFTMANCER_HOST:?pass root@HOST or set DRAFTMANCER_HOST}}"
ssh "$HOST" "bash /opt/draftmancer/deploy/hetzner/update.sh"
