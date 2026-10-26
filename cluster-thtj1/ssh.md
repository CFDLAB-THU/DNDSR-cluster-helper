# SSH access

Local client configuration inspected **2026-10-26**. Use `ssh thtj1`.
This entry reaches an operator-configured private login endpoint on port 22
through a local SOCKS5 proxy. Endpoint, proxy address/port, login and identity
remain private; the operator must supply or preconfigure them. The inspected
proxy command has the general form:

```sshconfig
Host <local-alias>
    HostName <private-login-endpoint>
    User <operator-provided-login>
    Port 22
    ProxyCommand nc -X 5 -x <local-socks-host>:<local-socks-port> %h %p
    ServerAliveInterval 45
    ForwardAgent no
```

The client-side SOCKS connection used to reach SSH is separate from any HTTP
download proxy forwarded into the remote session. Download forwarding, when
needed, must use a foreground ephemeral `-R
<proxy-port>:127.0.0.1:<proxy-port>` session. Unset HTTP proxy settings for jobs.
