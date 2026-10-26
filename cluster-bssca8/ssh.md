# SSH access

Local client configuration inspected **2026-10-26**. Use `ssh bssca8`.
The public gateway is `ssh.cn-zhongwei-1.paracloud.com`, port 22, with no
configured jump/proxy command. The gateway login contains a cluster suffix;
obtain its full value from the operator, not from the remote Linux username.
Keep login strings and identity paths in private SSH configuration.

The inspected client uses a 45-second keepalive and disables agent forwarding.
[`bssca8-bl`](../cluster-bssca8-bl/) is a separate login to the same platform;
its home, files and allocation association are independent.

For downloads use `ssh -o ExitOnForwardFailure=yes -R
<proxy-port>:127.0.0.1:<proxy-port> bssca8`, export
`LOCAL_PROXY_PORT=<proxy-port>` remotely and source `~/.setproxy.sh`. Keep the
session foreground-only; login-node routing can change on the next connection.
Unset proxies for builds and jobs.
