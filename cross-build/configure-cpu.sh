#!/usr/bin/env bash
# Configure and build with the captured target compiler on an x86-64 workstation.
set -euo pipefail
here=$(dirname "$(realpath "$0")")
export TARGET_SYSROOT=$(realpath -e "${TARGET_SYSROOT:?}")
source "$TARGET_SYSROOT/target.env"
ext="$TARGET_SYSROOT$EXT_ROOT"
export CROSS_MPI="$TARGET_SYSROOT$MPI_ROOT"
build=$(realpath -m "${BUILD_DIR:?}")
export CROSS_WRAPPER_DIR="$build/cross-wrappers" HOST_COMPILER_LIBS="$build/compiler-libs"
mkdir -p "$CROSS_WRAPPER_DIR" "$HOST_COMPILER_LIBS"
for name in cc cxx; do ln -sfn "$here/cpu-compiler.sh" "$CROSS_WRAPPER_DIR/$name"; done
for family in mpfr gmp mpc isl zstd; do
    while IFS= read -r -d '' lib; do
        ln -sfn "$lib" "$HOST_COMPILER_LIBS/${lib##*/}"
    done < <(find "$TARGET_SYSROOT" -name "lib$family.so*" -print0)
done
opts=()
for pair in ZLIB:z HDF5:hdf5 CGNS:cgns METIS:metis PARMETIS:parmetis; do
    key=${pair%%:*}; lib="$ext/lib/lib${pair#*:}.so"
    test -f "$lib"
    opts+=("-DDNDS_EXTERNAL_LIB_$key=$lib" "-DDNDS_EXTERNAL_INCLUDE_$key=$ext/include")
done
py=${PYTHON:-$(command -v python3)}
gen=()
if [[ ! -f "$build/CMakeCache.txt" ]]; then gen=(-G Ninja); fi
cmake -S "${SOURCE_DIR:?}" -B "$build" "${gen[@]}" -DCMAKE_TOOLCHAIN_FILE="$here/cpu-toolchain.cmake" \
    -DPython_EXECUTABLE="$py" -DPython_INCLUDE_DIR="$("$py" -c 'import sysconfig; print(sysconfig.get_path("include"))')" \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_SKIP_RPATH=ON -DDNDS_NATIVE_ARCH=OFF -DDNDS_USE_CCACHE=OFF \
    -DDNDS_LTO=OFF -DDNDS_USE_CUDA=OFF -DDNDS_USE_NCCL=OFF -DDNDS_USE_CANTERA=OFF -DDNDS_BUILD_TESTS=OFF \
    -DDNDS_CAUCHY_ENABLE_2D=OFF -DDNDS_CAUCHY_ENABLE_ACM=OFF -DDNDS_CFD_EXTERNALS_INSTALL="$ext" "${opts[@]}" "$@"
if [[ ${CONFIGURE_ONLY:-0} != 1 ]]; then cmake --build "$build" -t cauchy_solver -j "${JOBS:-4}"; fi
