#!/usr/bin/env bash
# Scheduled compilation only; no solver pilot or dry-run allocation.
set -euo pipefail
: "${SOURCE_DIR:?Set the source checkout path}"
: "${BUILD_DIR:?Set its paired build path}"
: "${CLUSTER_ENV:?Set the path to cluster-bssca/env/modules.sh}"
BUILD_CPUS="${BUILD_CPUS:-32}"
TARGET="${TARGET:-eulerSA3D}"
[[ "$BUILD_CPUS" =~ ^[1-9][0-9]*$ ]] && (( BUILD_CPUS <= 64 )) || exit 2
export SOURCE_DIR BUILD_DIR CLUSTER_ENV BUILD_CPUS TARGET
srun --partition=amd_256 --nodes=1 --ntasks=1 \
    --cpus-per-task="$BUILD_CPUS" --time=01:00:00 \
    bash -lc '
        set -euo pipefail
        source "$CLUSTER_ENV"
        cd "$SOURCE_DIR"
        command -v cmake mpicxx
        cmake --version
        mpicxx --showme:version
        mpicxx --showme:command
        cmake --build "$BUILD_DIR" --target "$TARGET" -j"$BUILD_CPUS"
    '
