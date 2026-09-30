#!/usr/bin/env bash
# Run on the login node with bounded parallelism; preserve stdout/stderr in a record.
set -euo pipefail
: "${SOURCE_DIR:?Export the absolute source directory}"
: "${BUILD_DIR:?Export the matching absolute build directory}"
: "${MODULE_ENV:?Export the absolute modules.sh path}"
: "${BUILD_LOG:?Export an absolute build-log path}"
[[ -d "$SOURCE_DIR/.git" && "$SOURCE_DIR" == /* && "$BUILD_DIR" == /* && "$BUILD_LOG" == /* ]]
source "$MODULE_ENV"
source "$SOURCE_DIR/venv/bin/activate"
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY all_proxy
export CC=mpicc CXX=mpicxx JOBS="${JOBS:-32}"
export CMAKE_BUILD_PARALLEL_LEVEL="$JOBS"
export MAKEFLAGS="${MAKEFLAGS:--j$JOBS}"
exec > >(tee -a "$BUILD_LOG") 2>&1
cd "$SOURCE_DIR"
echo "host=$(hostname) source_commit=$(git rev-parse HEAD) jobs=$JOBS"
module list 2>&1
for command_name in cmake gcc g++ as ld nm mpicc mpicxx mpirun; do
    command -v "$command_name"
done
cmake --version | sed -n '1p'
gcc --version | sed -n '1p'
as --version | sed -n '1p'
mpicc --showme:version
mpicc --showme:command
[[ "$(mpicc --showme:command)" == gcc ]]
[[ "$(command -v as)" == "$HOME/.local/dndsr-znver5-as/bin/as" ]]
[[ "$(command -v ld)" == /usr/bin/ld ]]
[[ "$(gcc -Q --help=target 2>/dev/null | awk '$1 == "-march=" {print $2}')" == znver5 ]]
[[ "$(gcc -Q --help=target 2>/dev/null | awk '$1 == "-mtune=" {print $2}')" == znver5 ]]
(
    cd external/cfd_externals
    python cfd_externals_build.py
)
# Recheck after the external builder before configuring DNDSR.
[[ "$(command -v as)" == "$HOME/.local/dndsr-znver5-as/bin/as" ]]
[[ "$(command -v ld)" == /usr/bin/ld ]]
[[ "$(gcc -Q --help=target 2>/dev/null | awk '$1 == "-march=" {print $2}')" == znver5 ]]
[[ "$(gcc -Q --help=target 2>/dev/null | awk '$1 == "-mtune=" {print $2}')" == znver5 ]]
export DNDS_TEST_NP_LIST='1;2;4;8' DNDS_TEST_OMP_THREADS=1 DNDS_TEST_TIMEOUT=120
generator_args=()
if [[ ! -f "$BUILD_DIR/CMakeCache.txt" ]]; then
    generator_args=(-G Ninja)
fi
cmake -S "$SOURCE_DIR" -B "$BUILD_DIR" "${generator_args[@]}" \
    -DCMAKE_BUILD_TYPE=Release -DDNDS_BUILD_TESTS=ON \
    -DCMAKE_EXE_LINKER_FLAGS=-Wl,--exclude-libs,ALL
cmake --build "$BUILD_DIR" --target eulerEX all_unit_tests -j "$JOBS"
dynamic_symbols=$(nm -DC "$BUILD_DIR/test/cpp/euler_test_evaluator_reactive")
if grep -q 'Eigen::SparseMatrix<double, 0, int>::resize' <<<"$dynamic_symbols"; then
    echo "Reactive test exports an interposable Eigen SparseMatrix symbol" >&2
    exit 1
fi
sha256sum "$BUILD_DIR/app/eulerEX.exe"
