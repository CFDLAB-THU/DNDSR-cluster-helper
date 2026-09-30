#!/usr/bin/env bash
# Expose only a reviewed new GNU assembler while preserving the system linker.
set -euo pipefail
: "${TOOLCHAIN_DIR:=$HOME/.local/share/dndsr-toolchains/binutils-2.46.1}"
if [[ -z "${REAL_AS:-}" ]]; then
    command -v pixi
    if [[ ! -f "$TOOLCHAIN_DIR/pixi.toml" ]]; then
        pixi init --channel conda-forge "$TOOLCHAIN_DIR"
    fi
    pixi add --manifest-path "$TOOLCHAIN_DIR/pixi.toml" 'binutils=2.46.1'
    mapfile -t assembler_candidates < <(
        find "$TOOLCHAIN_DIR/.pixi/envs/default/bin" -maxdepth 1 -type f \
            -name '*-as' -print
    )
    [[ "${#assembler_candidates[@]}" -eq 1 ]]
    REAL_AS=${assembler_candidates[0]}
fi
[[ "$REAL_AS" == /* && -x "$REAL_AS" ]]
"$REAL_AS" --version | sed -n '1p' | grep -F 'GNU Binutils) 2.46.1'
shim_dir="$HOME/.local/dndsr-znver5-as/bin"
mkdir -p "$shim_dir"
cat > "$shim_dir/as" <<WRAPPER
#!/usr/bin/env bash
exec "$REAL_AS" --compress-debug-sections=none "\$@"
WRAPPER
chmod 0755 "$shim_dir/as"
"$shim_dir/as" --version | sed -n '1p'
[[ "$(PATH="$shim_dir:$PATH" command -v as)" == "$shim_dir/as" ]]
[[ "$(PATH="$shim_dir:$PATH" command -v ld)" == /usr/bin/ld ]]
