# Security Policy

## Supported Versions

| Version | Supported |
| ------- | --------- |
| latest  | ✅        |

## Security Design

i-cherri is intentionally designed **without an authentication layer** for simplicity and maximum LAN performance.

**This means:**
- The server must only run on a trusted local network (home/office Wi-Fi)
- Never expose the server to the public internet via port forwarding or tunnels (e.g., Cloudflare Tunnel)
- Never run the iOS Shortcut sync on public Wi-Fi (libraries, cafes, schools)

## Reporting a Vulnerability

If you discover a security vulnerability, please **do not open a public GitHub issue**.

Report it privately by emailing: **yangwookee@gmail.com**

Include:
- A description of the vulnerability and potential impact
- Steps to reproduce
- Any suggested mitigations

You can expect a response within 72 hours. Once confirmed, a fix will be prioritized and a patched release will be issued.
