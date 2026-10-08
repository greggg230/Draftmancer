#!/usr/bin/env bash
# Pulls the deployed branch, rebuilds, and restarts Draftmancer. Run as root on
# the host (deploy.sh does this over SSH). Live sessions survive the restart.
set -euo pipefail
cd /opt/draftmancer
# The checkout belongs to the app user; run everything in it as that user.
run() { runuser -u draftmancer -- env PUPPETEER_SKIP_DOWNLOAD=true HUSKY=0 "$@"; }
BRANCH="$(run git rev-parse --abbrev-ref HEAD)"

run git fetch -q origin "$BRANCH"
run git reset -q --hard "origin/$BRANCH"
echo "==> $(run git log --oneline -1)"
run npm ci --no-audit --no-fund --loglevel=error
run npm run -s build-server
run npm run -s build-client >/dev/null
systemctl restart draftmancer

for _ in $(seq 1 60); do
	if curl -fs -o /dev/null http://127.0.0.1:3000/; then
		echo "==> draftmancer is up"
		exit 0
	fi
	sleep 2
done
echo "!! draftmancer did not come up; recent log:" >&2
journalctl -u draftmancer -n 40 --no-pager >&2
exit 1
