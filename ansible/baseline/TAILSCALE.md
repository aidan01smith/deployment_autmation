# TAILSCALE.md

The `tailscale/` role joins every guest to your Tailscale mesh VPN so each host
gets a stable private `100.x.y.z` address reachable from anywhere, independent
of LAN topology or NAT.

## Why it's in the baseline

Once a guest is on the tailnet you can manage and reach services without
exposing ports to the internet or fiddling with port-forwards — useful both for
remote administration and for letting services talk to each other privately.

## Auth

Uses an **OAuth client / auth key** rather than logging in interactively:

1. Create one at https://login.tailscale.com/admin/settings/oauth (or an auth
   key under *Settings → Keys*).
2. Copy `example_oauth_key.yml` to `tailscale_oauth_key.yml`, paste the key.
3. Encrypt it: `ansible-vault encrypt tailscale_oauth_key.yml`.
4. Run playbooks with `--ask-vault-pass`.

`--ssh` is passed to `tailscale up`, enabling Tailscale SSH so you can reach
nodes over the tailnet without managing keys separately.

## Files

- `tailscale.yml` — installs Tailscale from its apt repo and runs `tailscale up`.
- `example_oauth_key.yml` — template for the credential.
- `tailscale_oauth_key.yml` — your real (encrypted, gitignored) credential.

