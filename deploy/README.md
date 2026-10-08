# Self-hosting this fork

Production: Hetzner CX23 in Nuremberg (`root@2.31.56.61`, origin `https://2-31-56-61.sslip.io`).

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

## Windows desktop (`windows/`, not in use)

The first host. `windows/supervise.mjs` keeps a local build running on port 5250 (from
`.env`) and `windows/install-task.ps1` starts it at logon; `tailscale funnel --bg
--https=8443 http://127.0.0.1:5250` exposed it to the Worker. The logon task is disabled
and the funnel is off now that production runs on Hetzner.
