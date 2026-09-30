#!/usr/bin/env bash
# Prepare a DNDSR checkout and build the setup-phase C++ targets.
set -euo pipefail

: "${SOURCE_DIR:?Set SOURCE_DIR to the absolute ~/<name>/DNDSR checkout}"
: "${MODULE_ENV:?Set MODULE_ENV to the approved modules.sh}"
: "${HEADERONLYS_URL:?Resolve HEADERONLYS_URL from the current DNDSR CI workflow}"
: "${MESH_REPO_URL:?Resolve MESH_REPO_URL from the current DNDSR CI workflow}"
: "${BUILD_LOG:?Set BUILD_LOG to an absolute private log path}"
: "${LOCAL_PROXY_PORT:?Run downloads in the foreground forwarded-proxy shell}"
[[ "$SOURCE_DIR" == /* && "$BUILD_LOG" == /* && -d "$SOURCE_DIR/.git" ]]
[[ "${https_proxy:-}" == "http://127.0.0.1:${LOCAL_PROXY_PORT}" ]]
source "$MODULE_ENV"
for command_name in cmake gcc g++ mpicc mpicxx ninja uv python3.12; do
    command -v "$command_name"
done
[[ "$(mpicc --showme:command)" == gcc ]]
export CC=mpicc CXX=mpicxx JOBS="${JOBS:-32}" CMAKE_BUILD_PARALLEL_LEVEL="${JOBS:-32}"

mkdir -p "$(dirname "$BUILD_LOG")"
exec > >(tee -a "$BUILD_LOG") 2>&1
cd "$SOURCE_DIR"
echo "source_commit=$(git rev-parse HEAD) jobs=$JOBS host=$(hostname)"
module list 2>&1
[[ -z "$(git status --short)" ]] || {
    echo "Refusing setup in a checkout that was not initially clean" >&2
    exit 1
}

git submodule update --init --recursive --depth=1
if [[ ! -x venv/bin/python ]]; then
    uv venv --python python3.12 venv
fi
[[ "$(venv/bin/python -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')" == 3.12 ]]
uv pip install --python venv/bin/python pip
uv pip install --python venv/bin/python -r external/cfd_externals/requirements.txt

header_archive=external/external_headeronlys.tar.gz
curl -fL "$HEADERONLYS_URL" -o "$header_archive"
tar -xzf "$header_archive" -C external
for header_dir in boost CGAL doctest eigen fmt nlohmann; do
    [[ -d "external/$header_dir" ]]
done

mesh_scratch=$(mktemp -d)
trap 'rm -rf "$mesh_scratch"' EXIT
git clone --depth=1 "$MESH_REPO_URL" "$mesh_scratch/mesh-repo"
mkdir -p data/mesh
cp "$mesh_scratch/mesh-repo/data/mesh/"* data/mesh/
find data/mesh -maxdepth 1 -type f -print -quit | grep -q .

# All network work is now complete. Compilation must not inherit the tunnel.
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY all_proxy
unset no_proxy NO_PROXY LOCAL_PROXY_PORT

source venv/bin/activate
(
    cd external/cfd_externals
    CC=mpicc CXX=mpicxx python cfd_externals_build.py
)
compgen -G 'external/cfd_externals/install/lib/libcgns*' >/dev/null
compgen -G 'external/cfd_externals/install/lib/libcantera_shared*' >/dev/null
# zlib's configure removes its tracked generated header. Restore only this
# known build side effect, and only because the clean-check above established
# that it did not predate setup.
zlib_repo=external/cfd_externals/repos/zlib
zlib_status=$(git -C "$zlib_repo" status --short)
if [[ "$zlib_status" == ' D zconf.h' ]]; then
    git -C "$zlib_repo" restore -- zconf.h
elif [[ -n "$zlib_status" ]]; then
    echo "Unexpected zlib source changes after external build:" >&2
    printf '%s\n' "$zlib_status" >&2
    exit 1
fi

build_dir=${BUILD_DIR:-$SOURCE_DIR/build}
generator_args=()
if [[ ! -f "$build_dir/CMakeCache.txt" ]]; then
    generator_args=(-G Ninja)
fi
export DNDS_TEST_NP_LIST='1;2;4;8' DNDS_TEST_OMP_THREADS=1 DNDS_TEST_TIMEOUT=120
cmake -S "$SOURCE_DIR" -B "$build_dir" "${generator_args[@]}" \
    -DCMAKE_BUILD_TYPE=Release -DDNDS_BUILD_TESTS=ON \
    -DPython_EXECUTABLE="$SOURCE_DIR/venv/bin/python" \
    -DPython3_EXECUTABLE="$SOURCE_DIR/venv/bin/python"
cmake --build "$build_dir" --target eulerEX all_unit_tests -j "$JOBS"
test -x "$build_dir/app/eulerEX.exe"
sha256sum "$build_dir/app/eulerEX.exe"
ctest --test-dir "$build_dir" -N -E '^pytest_'
echo "C++ targets are ready. Do not build/install pybind modules or run Python tests in setup."
