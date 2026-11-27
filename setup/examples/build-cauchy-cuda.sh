#!/usr/bin/env bash
# Compile and link only. Run on a host where the cluster permits compilation.
set -eo pipefail
: "${MODULE_ENV:?Set the absolute path to the reviewed module layer}"
: "${SOURCE_DIR:?Set the canonical DNDSR source directory}"
: "${BUILD_DIR:?Set a dedicated CUDA build directory}"
SOURCE_DIR=$(realpath -e "$SOURCE_DIR")
BUILD_DIR=$(realpath -m "$BUILD_DIR")
source "$MODULE_ENV"
set -u
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY all_proxy
unset no_proxy NO_PROXY PROXY_URL LOCAL_PROXY_PORT
export CUDA_VISIBLE_DEVICES=
jobs=${JOBS:-32}
attempt_limit=${BUILD_MAX_ATTEMPTS:-12}
[[ $jobs =~ ^[1-9][0-9]*$ && $attempt_limit =~ ^[1-9][0-9]*$ ]] || {
    echo "JOBS and BUILD_MAX_ATTEMPTS must be positive integers" >&2
    exit 2
}

for wrapper in mpicc mpicxx; do
    "$wrapper" --showme:version
    "$wrapper" --showme:command
done
gcc_path=$(command -v gcc)
cxx_path=$(command -v g++)
[[ $(command -v "$(mpicc --showme:command)") == "$gcc_path" ]]
[[ $(command -v "$(mpicxx --showme:command)") == "$cxx_path" ]]
"$CUDA_HOME/bin/nvcc" --version
generator=()
[[ -f "$BUILD_DIR/CMakeCache.txt" ]] || generator=(-G Ninja)
ninja_program=()
[[ -z ${NINJA_PROGRAM:-} ]] || ninja_program=(-DCMAKE_MAKE_PROGRAM="$NINJA_PROGRAM")
cmake -S "$SOURCE_DIR" -B "$BUILD_DIR" "${generator[@]}" "${ninja_program[@]}" \
    -DCMAKE_BUILD_TYPE=Release -DDNDS_BUILD_TESTS=OFF \
    -DDNDS_USE_CUDA=ON -DDNDS_USE_NCCL=ON \
    -DCMAKE_C_COMPILER="$(command -v mpicc)" \
    -DCMAKE_CXX_COMPILER="$(command -v mpicxx)" \
    -DCMAKE_CUDA_COMPILER="$CUDA_HOME/bin/nvcc" \
    -DCMAKE_CUDA_HOST_COMPILER="$cxx_path" \
    -DCMAKE_CUDA_ARCHITECTURES="$DNDS_CUDA_ARCHITECTURES" \
    -DCUDAToolkit_ROOT="$CUDA_HOME" -DNCCL_ROOT="$NCCL_ROOT" \
    -DDNDS_NCCL_LIBRARY="$(realpath -e "$NCCL_ROOT/lib/libnccl.so")" \
    -DDNDS_NCCL_INCLUDE_DIR="$NCCL_ROOT/include" \
    -DDNDS_CFD_EXTERNALS_INSTALL="${EXTERNALS_PREFIX:-$SOURCE_DIR/external/cfd_externals/install}" \
    -DPython_EXECUTABLE="$SOURCE_DIR/venv/bin/python" \
    -DPython3_EXECUTABLE="$SOURCE_DIR/venv/bin/python" \
    -DCMAKE_EXE_LINKER_FLAGS=-Wl,--exclude-libs,ALL

native_options=()
if grep -Eq '^CMAKE_GENERATOR:INTERNAL=Ninja( Multi-Config)?$' "$BUILD_DIR/CMakeCache.txt"; then
    native_options=(-- -k 0)
fi
for ((attempt = 1; attempt <= attempt_limit; attempt++)); do
    log="$BUILD_DIR/build-attempt-$(date +%Y%m%d-%H%M%S)-$$-$attempt.log"
    printf 'Cauchy build attempt %d/%d with %d workers\n' "$attempt" "$attempt_limit" "$jobs"
    if cmake --build "$BUILD_DIR" --target cauchy_solver -j "$jobs" "${native_options[@]}" 2>&1 | tee "$log"; then
        break
    else
        build_status=${PIPESTATUS[0]}
    fi
    interruption='died due to signal (9|15)|\[code=(9|15|130|137|143)\]|(Killed|Terminated) signal|interrupted by user|^Killed$|^Terminated$'
    if (( attempt == attempt_limit )) ||
        { [[ $build_status != 130 && $build_status != 137 && $build_status != 143 ]] &&
          ! grep -aqE "$interruption" "$log"; }; then
        echo "Cauchy build stopped. See $log" >&2
        exit 1
    fi
    echo "Compiler interruption detected. Resuming the existing build tree."
done
executable="$BUILD_DIR/app/cauchy.exe"
test -x "$executable"
sha256sum "$executable"
readelf -d "$executable"
images=$("$CUDA_HOME/bin/cuobjdump" --list-elf "$executable")
IFS=';' read -ra architectures <<< "$DNDS_CUDA_ARCHITECTURES"
for architecture in "${architectures[@]}"; do
    sm=${architecture%-real}
    if [[ $sm == *-virtual ]]; then
        echo "Expected a native CUDA target, received $architecture" >&2
        exit 1
    fi
    if [[ $images != *".sm_$sm.cubin"* ]]; then
        echo "Cauchy executable has no sm_$sm device image" >&2
        exit 1
    fi
    echo "Cauchy executable includes an sm_$sm device image."
done
libraries=$(ldd "$executable")
printf '%s\n' "$libraries"
loaded_nccl=$(awk '$1 ~ /^libnccl[.]so/ && $2 == "=>" {print $3; exit}' <<< "$libraries")
[[ -f $loaded_nccl && $loaded_nccl -ef "$NCCL_ROOT/lib/libnccl.so" ]] || {
    echo "Loaded NCCL ($loaded_nccl) differs from selected NCCL ($NCCL_ROOT)" >&2
    exit 1
}
for library in libmpi libnccl libcudart; do
    if ! grep -Eq "^[[:space:]]*${library}\\.so([.][^[:space:]]+)?[[:space:]]+=>[[:space:]]+/" <<<"$libraries"; then
        echo "Missing expected shared library: $library" >&2
        exit 1
    fi
done
# The CUDA driver is supplied by the compute node. Keep toolkit driver stubs
# out of LD_LIBRARY_PATH, and allow only the driver to be absent on the login.
if awk '/=> not found/ && $1 != "libcuda.so.1" { missing=1 } END { exit !missing }' <<<"$libraries"; then
    echo "Unexpected unresolved runtime library" >&2
    exit 1
fi
echo "Cauchy CUDA compile/link complete."
