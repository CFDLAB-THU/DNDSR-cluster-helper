# SSH access

Local client configuration inspected **2026-10-26**. Use `ssh bsscm8`.
The public gateway is `ssh.cn-zhongwei-1.paracloud.com`, port 22, with no
configured jump/proxy command. Obtain the cluster-qualified gateway login and
identity from the operator; keep them in private SSH configuration. Gateway
login syntax need not match the Linux username.

The inspected client uses a 45-second keepalive and disables agent forwarding.
For downloads use a foreground `ssh -o ExitOnForwardFailure=yes -R
<proxy-port>:127.0.0.1:<proxy-port> bsscm8` session, then remotely export
`LOCAL_PROXY_PORT=<proxy-port>` and source `~/.setproxy.sh`. Reconnect with a
new tunnel for later downloads because login routing can change. Unset proxies
for compilation and jobs; do not persist forwarding.
