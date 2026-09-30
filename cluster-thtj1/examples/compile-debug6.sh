#!/usr/bin/env bash
# Build one target on a debug6 compute node. The build must already be configured.
set -euo pipefail

: "${SOURCE_DIR:?Set SOURCE_DIR to the absolute source-tree path}"
: "${BUILD_DIR:?Set BUILD_DIR to the matching configured build-tree path}"
: "${TARGET:?Set TARGET to the CMake target to build}"
: "${COMM_ENV:?Set COMM_ENV to the absolute path of env/ucx-glex.sh}"

BUILD_CPUS="${BUILD_CPUS:-16}"

[[ -d "$SOURCE_DIR" ]] || { echo "missing source directory: $SOURCE_DIR" >&2; exit 2; }
[[ -d "$BUILD_DIR" ]] || { echo "missing build directory: $BUILD_DIR" >&2; exit 2; }
[[ -f "$COMM_ENV" ]] || { echo "missing communication environment: $COMM_ENV" >&2; exit 2; }
[[ "$BUILD_CPUS" =~ ^[1-9][0-9]*$ ]] || { echo "BUILD_CPUS must be positive" >&2; exit 2; }
(( BUILD_CPUS <= 56 )) || { echo "BUILD_CPUS must not exceed one node (56)" >&2; exit 2; }

export SOURCE_DIR BUILD_DIR TARGET COMM_ENV BUILD_CPUS
srun \
    --partition=debug6 \
    --nodes=1 \
    --ntasks=1 \
    --cpus-per-task="$BUILD_CPUS" \
    --time=00:30:00 \
    bash -lc '
        set -euo pipefail
        source "$COMM_ENV"
        cd "$SOURCE_DIR"
        echo "host=$(hostname) source=$SOURCE_DIR build=$BUILD_DIR target=$TARGET cpus=$BUILD_CPUS"
        command -v mpicxx
        mpicxx --showme:version 2>/dev/null || true
        cmake --build "$BUILD_DIR" --target "$TARGET" -j"$BUILD_CPUS"
    '
