# SSH access

Local client configuration inspected **2026-10-26**. Use `ssh bssca8`.
The public gateway is `ssh.cn-zhongwei-1.paracloud.com`, port 22, with no
configured jump/proxy command. The gateway login contains a cluster suffix;
obtain its full value from the operator, not from the remote Linux username.
Keep login strings and identity paths in private SSH configuration.

The inspected client uses a 45-second keepalive and disables agent forwarding.
[`bssca8-bl`](../cluster-bssca8-bl/) is a separate login to the same platform;
its home, files and allocation association are independent.

For downloads, use a cluster-provided proxy or a local SSH `-R` forwarded
proxy supplied by the operator. Keep endpoints, ports and client configuration
private. If forwarding is used, keep it ephemeral because login routing can
change. Clear proxy settings before compilation and compute jobs.
