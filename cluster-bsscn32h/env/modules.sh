#!/usr/bin/env bash
# Source this file in Bash before configuring, building or launching.
if ! type module >/dev/null 2>&1; then
    source /home/bingxing2/apps/tools/modules/init/profile.sh || return
fi
module use /home/bingxing2/apps/modules || return
module purge || return

# Older login setups prepend a private CUDA/NCCL installation outside modules.
# Remove just those entries so FindCUDAToolkit and the loader select the same stack.
_n32_drop_legacy_paths() {
    local name entry joined
    local -a entries kept
    for name in PATH LD_LIBRARY_PATH LIBRARY_PATH CPATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH CMAKE_PREFIX_PATH PKG_CONFIG_PATH; do
        [[ -v $name ]] || continue
        IFS=: read -r -a entries <<< "${!name}"
        kept=()
        for entry in "${entries[@]}"; do
            case "$entry" in
                "$HOME"/.local/opt/dndsr/cuda-*|"$HOME"/.local/opt/dndsr/nccl-*) ;;
                *) kept+=("$entry") ;;
            esac
        done
        joined=$(IFS=:; printf '%s' "${kept[*]}")
        export "$name=$joined"
    done
}
_n32_drop_legacy_paths
unset -f _n32_drop_legacy_paths
unset CUDA_HOME CUDA_PATH CUDAToolkit_ROOT NCCL_HOME NCCL_ROOT
module load compilers/gcc/13.2.0 cmake/3.31.6 \
    hpcx/hpcx-v2.50-gcc-doca_ofed-kylin10-cuda12-aarch64/hpcx \
    compilers/cuda/12.8 nccl/2.26.5-1_cuda12.8 || return
export NCCL_ROOT=/home/bingxing2/apps/nccl/2.26.5-1_cuda12.8/build
export OMPI_CC="$(command -v gcc)" OMPI_CXX="$(command -v g++)"
export CC=mpicc CXX=mpicxx
export JOBS="${JOBS:-16}" DNDS_CUDA_ARCHITECTURES=80
export PATH="$CUDA_HOME/bin:$HOME/.pixi/bin:$HOME/.local/bin:$PATH"
alias sq="squeue -o \"%.12i %.9P %.80j %.8u %.2t %.10M %.6D %R\""
