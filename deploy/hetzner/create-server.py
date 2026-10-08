"""Creates the Draftmancer server on Hetzner Cloud (stdlib only).

    python deploy/hetzner/create-server.py --list            # server types + prices at --location
    python deploy/hetzner/create-server.py --type cpx11      # create it (idempotent by --name)

The API token is read from $HCLOUD_TOKEN or ~/.config/draftmancer/hcloud_token.
Prints the server's IPv4 and the sslip.io hostname to pass to setup.sh.
"""

import argparse
import json
import os
import pathlib
import sys
import time
import urllib.error
import urllib.request

API = "https://api.hetzner.cloud/v1"


def token() -> str:
    if os.environ.get("HCLOUD_TOKEN"):
        return os.environ["HCLOUD_TOKEN"].strip()
    path = pathlib.Path.home() / ".config" / "draftmancer" / "hcloud_token"
    if not path.exists():
        sys.exit(f"no token: set HCLOUD_TOKEN or write it to {path}")
    return path.read_text().strip()


def call(method: str, path: str, body: dict | None = None) -> dict:
    req = urllib.request.Request(
        API + path,
        method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={"Authorization": f"Bearer {token()}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read() or b"{}")
    except urllib.error.HTTPError as err:
        sys.exit(f"{method} {path} -> {err.code}: {err.read().decode()}")


def list_types(location: str) -> None:
    rows = []
    for t in call("GET", "/server_types?per_page=50")["server_types"]:
        if t.get("deprecation"):
            continue
        price = next((p for p in t["prices"] if p["location"] == location), None)
        if price is None:
            continue
        rows.append((float(price["price_monthly"]["gross"]), t))
    print(f"{'type':<8} {'arch':<5} {'vcpu':>4} {'mem':>5} {'disk':>5}  monthly@{location}")
    for monthly, t in sorted(rows, key=lambda r: r[0]):
        print(f"{t['name']:<8} {t['architecture']:<5} {t['cores']:>4} {t['memory']:>4g}G {t['disk']:>4}G  {monthly:.2f}")


def ensure_ssh_key(pubkey_path: pathlib.Path) -> int:
    pub = pubkey_path.read_text().strip()
    for key in call("GET", "/ssh_keys")["ssh_keys"]:
        if key["public_key"].split()[:2] == pub.split()[:2]:
            return key["id"]
    return call("POST", "/ssh_keys", {"name": f"draftmancer-{pubkey_path.stem}", "public_key": pub})["ssh_key"]["id"]


def create(args: argparse.Namespace) -> None:
    existing = call("GET", f"/servers?name={args.name}")["servers"]
    if existing:
        server = existing[0]
        print(f"server '{args.name}' already exists")
    else:
        key_id = ensure_ssh_key(pathlib.Path(args.ssh_key).expanduser())
        server = call(
            "POST",
            "/servers",
            {
                "name": args.name,
                "server_type": args.type,
                "location": args.location,
                "image": "ubuntu-24.04",
                "ssh_keys": [key_id],
                "public_net": {"enable_ipv4": True, "enable_ipv6": True},
                "labels": {"app": "draftmancer"},
            },
        )["server"]
        print(f"created server '{args.name}' ({args.type} @ {args.location}), waiting for it to boot...")
    for _ in range(60):
        server = call("GET", f"/servers/{server['id']}")["server"]
        if server["status"] == "running":
            break
        time.sleep(3)
    ip = server["public_net"]["ipv4"]["ip"]
    print(f"status:    {server['status']}")
    print(f"ipv4:      {ip}")
    print(f"site_host: {ip.replace('.', '-')}.sslip.io")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--list", action="store_true", help="list server types and prices, then exit")
    ap.add_argument("--name", default="draftmancer")
    ap.add_argument("--type", help="server type, e.g. cpx11")
    ap.add_argument("--location", default="hil", help="hil (Oregon), ash (Virginia), nbg1/fsn1/hel1 (EU)")
    ap.add_argument("--ssh-key", default="~/.ssh/id_ed25519.pub")
    args = ap.parse_args()
    if args.list:
        list_types(args.location)
    elif args.type:
        create(args)
    else:
        ap.error("pass --list or --type")


if __name__ == "__main__":
    main()
