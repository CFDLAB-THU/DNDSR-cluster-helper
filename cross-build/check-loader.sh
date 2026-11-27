#!/usr/bin/env bash
# Login-node check for a trusted ELF. This never invokes its entry point.
set -euo pipefail
binary=$(realpath -e "${1:?Specify the target executable}")
readelf -lW "$binary" | grep 'Requesting program interpreter'
readelf -dW "$binary" | grep -E 'NEEDED|RPATH|RUNPATH'
sha256sum "$binary"
if [[ -n ${EXPECTED_SHA256:-} ]]; then
    printf '%s  %s\n' "$EXPECTED_SHA256" "$binary" | sha256sum -c -
fi
out=$(mktemp -d)
trap 'rm -rf -- "$out"' EXIT
ldd "$binary" > "$out/normal"
cat "$out/normal"
if grep -Eq 'not found|undefined symbol' "$out/normal"; then
    if grep -E 'not found|undefined symbol' "$out/normal" | grep -Ev '^[[:space:]]*libcuda\.so\.1 => not found[[:space:]]*$'; then exit 1; fi
    : "${DRIVER_STUB:?Login lacks libcuda.so.1; point DRIVER_STUB at the matching toolkit stub for relocation only}"
    ln -s "$(realpath -e "$DRIVER_STUB")" "$out/libcuda.so.1"
fi
LD_LIBRARY_PATH="$out${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" ldd -r "$binary" > "$out/relocations" 2>&1
cat "$out/relocations"
if grep -E 'not found|undefined symbol|not a dynamic executable' "$out/relocations"; then exit 1; fi
