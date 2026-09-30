# Source this file after opening the matching foreground SSH reverse tunnel.
: "${LOCAL_PROXY_PORT:?Export LOCAL_PROXY_PORT before sourcing .setproxy.sh}"
if [[ ! "$LOCAL_PROXY_PORT" =~ ^[0-9]+$ ]] || (( LOCAL_PROXY_PORT < 1 || LOCAL_PROXY_PORT > 65535 )); then
    echo "LOCAL_PROXY_PORT must be an integer from 1 to 65535" >&2
    return 2
fi
export http_proxy="http://127.0.0.1:${LOCAL_PROXY_PORT}"
export https_proxy="$http_proxy"
export HTTP_PROXY="$http_proxy"
export HTTPS_PROXY="$http_proxy"
export no_proxy="localhost,127.0.0.1"
export NO_PROXY="$no_proxy"
