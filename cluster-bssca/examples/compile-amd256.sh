#!/usr/bin/env bash
# Normal BSSCA login-node build; historical filename retained for callers.
# No allocation, MPI test or solver is started. If killed, preserve this
# attempt's log and rerun the same command with 16 workers and the partial cache.
set -euo pipefail
: "${SOURCE_DIR:?Set the source checkout path}"
: "${BUILD_DIR:?Set its paired build path}"
: "${CLUSTER_ENV:?Set the approved scoped cluster environment script}"
BUILD_CPUS="${BUILD_CPUS:-16}"
TARGET="${TARGET:-eulerSA3D}"
if [[ "$BUILD_CPUS" != 16 ]]; then
    printf 'BSSCA standalone login builds use 16 compiler workers, including retries.\n' >&2
    exit 2
fi
source "$CLUSTER_ENV"
cd "$SOURCE_DIR"
command -v cmake mpicxx
cmake --version
mpicxx --showme:version
mpicxx --showme:command
exec cmake --build "$BUILD_DIR" --target "$TARGET" -j"$BUILD_CPUS"
