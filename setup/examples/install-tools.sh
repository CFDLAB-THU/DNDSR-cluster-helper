#!/usr/bin/env bash
# Run inside the foreground reverse-tunnel shell after sourcing .setproxy.sh.
set -euo pipefail

: "${LOCAL_PROXY_PORT:?Open the ephemeral tunnel and source ~/.setproxy.sh first}"
[[ "${https_proxy:-}" == "http://127.0.0.1:${LOCAL_PROXY_PORT}" ]]

curl -fsSL https://pixi.sh/install.sh | bash
export PATH="$HOME/.pixi/bin:$HOME/.local/bin:$PATH"
curl -LsSf https://astral.sh/uv/install.sh | sh

pixi global install ninja
pixi global install doxygen
uv python install 3.12 --default

pixi --version
uv --version
ninja --version
doxygen --version | sed -n '1p'
uv python find 3.12
[[ "$(command -v python3)" == "$HOME/.local/bin/python3" ]]
python3 --version
python3.12 --version
echo "Tool layer installed. Close the foreground SSH session when downloads finish."
