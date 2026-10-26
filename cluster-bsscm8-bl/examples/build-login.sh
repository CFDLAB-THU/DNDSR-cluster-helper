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
exec > >(tee -a "$BUILD_LOG") 2>&1
cd "$SOURCE_DIR"
echo "host=$(hostname) source_commit=$(git rev-parse HEAD) jobs=$JOBS"
module list 2>&1
for command_name in cmake gcc g++ as mpicc mpicxx mpirun; do
    command -v "$command_name"
done
cmake --version | sed -n '1p'
gcc --version | sed -n '1p'
as --version | sed -n '1p'
mpicc --showme:version
mpicc --showme:command
[[ "$(mpicc --showme:command)" == gcc ]]
[[ "$(mpicxx --showme:command)" == g++ ]]
(
    cd external/cfd_externals
    python cfd_externals_build.py
)
export DNDS_TEST_NP_LIST='1;2;4;8' DNDS_TEST_OMP_THREADS=1 DNDS_TEST_TIMEOUT=120
generator_args=()
if [[ ! -f "$BUILD_DIR/CMakeCache.txt" ]]; then
    generator_args=(-G Ninja)
fi
cmake -S "$SOURCE_DIR" -B "$BUILD_DIR" "${generator_args[@]}" \
    -DCMAKE_BUILD_TYPE=Release -DDNDS_BUILD_TESTS=ON \
    -DDNDS_DIST_MT_USE_OMP=OFF \
    -DCMAKE_EXE_LINKER_FLAGS=-Wl,--exclude-libs,ALL \
    -DPython_EXECUTABLE="$SOURCE_DIR/venv/bin/python" \
    -DPython3_EXECUTABLE="$SOURCE_DIR/venv/bin/python"
# For the documented f080ba5 test-only missing-header workaround, first
# configure with -DCMAKE_PROJECT_TOP_LEVEL_INCLUDES=<profile>/cmake/test-localchecks-compat.cmake.
# Do not apply that workaround blindly to a different source revision.
cmake --build "$BUILD_DIR" --target eulerEX all_unit_tests -j "$JOBS"
# f080ba5 registers this C++ test but omits it from all_unit_tests.
if [[ $(git rev-parse HEAD) == f080ba55627d93a7879ac59be172e25156644e76 ]]; then
    cmake --build "$BUILD_DIR" --target euler_test_reactive_split_indicator -j "$JOBS"
fi
sha256sum "$BUILD_DIR/app/eulerEX.exe"
