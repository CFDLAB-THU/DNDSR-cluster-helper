#!/usr/bin/env bash
# Source this file in Bash before configuring or building DNDSR.
source /etc/profile.d/modules.sh || return
module purge || return
module load gcc/14.2.0 cmake/4.2.0 nvhpc/25.11-hpcx-cuda13 cuda/13.0 || return

case "${DNDSR_N46_GPU_FAMILY:-a800}" in
    a800)
        # The site's NCCL 2.27 module requires CUDA 12.8. Select the
        # verified sm_80 library directly and keep the CUDA 13.0 toolkit.
        export NCCL_ROOT=/data/apps/nccl/nccl-2.27.3-1/build
        test -r "$NCCL_ROOT/include/nccl.h" && test -r "$NCCL_ROOT/lib/libnccl.so" || return 1
        export LD_LIBRARY_PATH="$NCCL_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
        export LIBRARY_PATH="$NCCL_ROOT/lib${LIBRARY_PATH:+:$LIBRARY_PATH}"
        export CPATH="$NCCL_ROOT/include${CPATH:+:$CPATH}"
        export C_INCLUDE_PATH="$NCCL_ROOT/include${C_INCLUDE_PATH:+:$C_INCLUDE_PATH}"
        export DNDS_CUDA_ARCHITECTURES=80
        ;;
    hopper)
        module load nccl/2.28_cuda13.0 || return
        export NCCL_ROOT=/data/apps/nccl/nccl-2.28.9-1/build
        export DNDS_CUDA_ARCHITECTURES=90
        ;;
    *)
        printf 'DNDSR_N46_GPU_FAMILY must be a800 or hopper\n' >&2
        return 1
        ;;
esac
export OMPI_CC="$(command -v gcc)" OMPI_CXX="$(command -v g++)"
export CC=mpicc CXX=mpicxx
export JOBS="${JOBS:-8}"
export PATH="$CUDA_HOME/bin:$HOME/.pixi/bin:$HOME/.local/bin:$PATH"
alias sq="squeue -o \"%.12i %.9P %.80j %.8u %.2t %.10M %.6D %R\""
