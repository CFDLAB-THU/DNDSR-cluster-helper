# SSH access

Local client configuration inspected **2026-10-26**. Use `ssh bsscm9`.
The public gateway is `ssh.cn-zhongwei-1.paracloud.com`, port 22, with no
configured jump/proxy command. Obtain the cluster-qualified gateway login and
identity from the operator; keep them in private SSH configuration. Gateway
login syntax need not match the Linux username.

The inspected client uses a 45-second keepalive and disables agent forwarding.
For downloads, use a cluster-provided proxy or a local SSH `-R` forwarded
proxy supplied by the operator. Keep endpoints, ports and client configuration
private. If forwarding is used, keep it ephemeral because login routing can
change. Clear proxy settings before compilation and compute jobs.
