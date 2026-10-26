# Source with an operator-supplied cluster-provided or SSH-forwarded proxy URL.
if [[ -n ${PROXY_URL:-} ]]; then
    case "$PROXY_URL" in
        http://*|https://*|socks5://*|socks5h://*) ;;
        *) echo "PROXY_URL must include a supported proxy scheme" >&2; return 2 ;;
    esac
elif [[ -n ${LOCAL_PROXY_PORT:-} ]]; then
    # Retain compatibility with existing forwarded-proxy shell sessions.
    if [[ ! "$LOCAL_PROXY_PORT" =~ ^[0-9]+$ ]] || (( LOCAL_PROXY_PORT < 1 || LOCAL_PROXY_PORT > 65535 )); then
        echo "LOCAL_PROXY_PORT must be an integer from 1 to 65535" >&2
        return 2
    fi
    PROXY_URL="http://127.0.0.1:${LOCAL_PROXY_PORT}"
else
    echo "Export the operator-provided PROXY_URL before sourcing .setproxy.sh" >&2
    return 2
fi
export http_proxy="$PROXY_URL"
export https_proxy="$http_proxy"
export HTTP_PROXY="$http_proxy"
export HTTPS_PROXY="$http_proxy"
export no_proxy="localhost,127.0.0.1"
export NO_PROXY="$no_proxy"
