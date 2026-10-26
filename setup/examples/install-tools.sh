#!/usr/bin/env bash
# Use the current shell's cluster-provided or SSH-forwarded proxy if needed.
set -euo pipefail

curl -fsSL https://pixi.sh/install.sh | bash
export PATH="$HOME/.pixi/bin:$HOME/.local/bin:$PATH"
curl -LsSf https://astral.sh/uv/install.sh | sh

pixi global install ninja
pixi global install doxygen
pixi global install uv
uv python install 3.12 --default

pixi --version
uv --version
ninja --version
doxygen --version | sed -n '1p'
uv python find 3.12
[[ "$(command -v python3)" == "$HOME/.local/bin/python3" ]]
python3 --version
python3.12 --version
echo "Tool layer installed. Clear download proxy settings when finished."
