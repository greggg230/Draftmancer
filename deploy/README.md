# Self-hosting this fork

Public URL: https://draftmancer.greggg230.com, served by the Cloudflare Worker in
`cloudflare/`. The Worker's custom domain creates the DNS record, and the Worker
proxies every request (WebSockets included) to `ORIGIN` in `cloudflare/wrangler.jsonc`.
Changing hosts means changing `ORIGIN` and running `npx wrangler deploy` in `cloudflare/`.

## Hetzner (`hetzner/`)

1. Put a Read & Write API token in `~/.config/draftmancer/hcloud_token`.
2. `python deploy/hetzner/create-server.py --list` to compare prices, then
   `python deploy/hetzner/create-server.py --type <type>`. Prints the IP and an sslip.io hostname.
3. `ssh root@IP "SITE_HOST=<sslip host> bash -s" < deploy/hetzner/setup.sh` installs Node 22,
   Caddy (Let's Encrypt for the sslip.io host), a systemd unit, and builds the branch.
4. Point `ORIGIN` at `https://<sslip host>` and redeploy the Worker.

Updates: push the branch, then `deploy/hetzner/deploy.sh root@IP`.
Server config lives in `/etc/draftmancer.env`; logs via `journalctl -u draftmancer`.

## Windows desktop (`windows/`)

`windows/supervise.mjs` keeps a local build running on port 5250 (from `.env`);
`windows/install-task.ps1` starts it at logon. Tailscale Funnel on port 8443 makes it
reachable for the Worker.
