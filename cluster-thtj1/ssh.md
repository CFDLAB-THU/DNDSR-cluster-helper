# SSH access

Local client configuration inspected **2026-10-26**. Use `ssh thtj1`.
This entry reaches an operator-configured private login endpoint on port 22.
Obtain the endpoint, login, identity and any required SSH access route from the
operator's private configuration. The inspected client uses a 45-second
keepalive and disables agent forwarding.

For downloads, use a cluster-provided proxy or a local SSH `-R` forwarded
proxy supplied by the operator. Keep endpoints, ports and client configuration
private. Clear download proxy settings before compute jobs.
