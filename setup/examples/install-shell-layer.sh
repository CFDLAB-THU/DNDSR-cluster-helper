#!/usr/bin/env bash
# Install reviewed, cluster-neutral Bash helpers and an approved module layer.
set -euo pipefail

: "${SETUP_ROOT:?Set SETUP_ROOT to this setup directory}"
: "${MODULE_ENV_FILE:?Set MODULE_ENV_FILE to the approved modules.sh}"
[[ -d "$SETUP_ROOT/bash" && -f "$MODULE_ENV_FILE" ]]

required_alias='alias sq="squeue -o \"%.12i %.9P %.80j %.8u %.2t %.10M %.6D %R\""'
grep -Fqx "$required_alias" "$MODULE_ENV_FILE" || {
    echo "Approved module layer is missing the exact sq alias" >&2
    exit 1
}

timestamp=$(date +%Y%m%d-%H%M%S)
install_one()
{
    local source_file=$1 destination=$2
    if [[ -e "$destination" ]]; then
        cp -a "$destination" "$destination.before-dndsr-$timestamp"
    fi
    install -m 0644 "$source_file" "$destination"
}

install_one "$SETUP_ROOT/bash/.bashrc_utils.sh" "$HOME/.bashrc_utils.sh"
install_one "$SETUP_ROOT/bash/.inputrc" "$HOME/.inputrc"
install_one "$SETUP_ROOT/bash/.setproxy.sh" "$HOME/.setproxy.sh"
install_one "$SETUP_ROOT/bash/.unsetproxy.sh" "$HOME/.unsetproxy.sh"
install_one "$MODULE_ENV_FILE" "$HOME/.bashrc_dndsr"
path_line='export PATH="$HOME/.pixi/bin:$HOME/.local/bin:$PATH"'
grep -Fqx "$path_line" "$HOME/.bashrc_dndsr" || printf '%s\n' "$path_line" >> "$HOME/.bashrc_dndsr"

ensure_source_line()
{
    local line=$1
    grep -Fqx "$line" "$HOME/.bashrc" || printf '\n%s\n' "$line" >> "$HOME/.bashrc"
}
ensure_source_line '[[ -f ~/.bashrc_utils.sh ]] && source ~/.bashrc_utils.sh'
ensure_source_line '[[ -f ~/.bashrc_dndsr ]] && source ~/.bashrc_dndsr'

bash -n "$HOME/.bashrc" "$HOME/.bashrc_utils.sh" "$HOME/.bashrc_dndsr" \
    "$HOME/.setproxy.sh" "$HOME/.unsetproxy.sh"
grep -Fqx "$required_alias" "$HOME/.bashrc_dndsr"
grep -Fqx "$path_line" "$HOME/.bashrc_dndsr"
echo "Shell layer installed; previous files, when present, use suffix .before-dndsr-$timestamp"
