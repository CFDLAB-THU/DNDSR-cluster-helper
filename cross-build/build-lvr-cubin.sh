#!/usr/bin/env bash
# Workstation build of the LVR device translation unit for one target SM.
set -euo pipefail
sm=${1:?Specify SM 80, 89 or 120}
out=${2:?Specify output cubin}
case $sm in 80|89|120) ;; *) echo "Unsupported profile SM: $sm" >&2; exit 2;; esac
src=$(realpath -e "${SOURCE_DIR:?}")
ext=${EXTERNAL_DIR:-$src/external}
cuda=$(realpath -e "${CUDA_HOME:?Select an x86-64 toolkit for the target CUDA family}")
read -ra mpi_includes <<< "$(mpicc --showme:incdirs)"
includes=("-I$src/src" "-I$src/src/DNDS/Compat/Include" "-I$src/src/Geom/Compat/Include" "-I$src/src/CFV/Compat/Include")
for path in "${mpi_includes[@]}" "$cuda"/targets/x86_64-linux/include{,/cccl}; do includes+=("-I$path"); done
for sub in eigen boost nlohmann CGAL/include cppcodec exprtk argparse/include/argparse fmt/include spdlog/include cfd_externals/install/include; do
    includes+=("-I$ext/$sub")
done
"$cuda/bin/nvcc" --cubin -arch="sm_$sm" -std=c++17 -O2 -ccbin "${CUDAHOSTCXX:-g++}" \
    --expt-relaxed-constexpr --extended-lambda -diag-suppress=128 -diag-suppress=177 -diag-suppress=2417 \
    -DDNDS_USE_CUDA -D__DNDS_REALLY_COMPILING__ -DOMPI_SKIP_MPICXX=1 -DDNDS_RUNTIME_ARRAY_BOUNDS_CHECKS=0 \
    "${includes[@]}" "$src/src/Cauchy/Discretization/CUDA/FiniteVolumeLimitedVRKernels.cu" -o "$out"
symbols=$(readelf -Ws "$out")
for name in PrepareLVRScalarsAndTargetKernel BuildLVRFaceSensorsKernel; do grep -q "$name" <<<"$symbols"; done
sha256sum "$out"
