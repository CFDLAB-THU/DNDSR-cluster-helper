#!/usr/bin/env bash
# Source this file in Bash before configuring or building DNDSR.
if ! type module >/dev/null 2>&1; then
    source /home/bingxing2/apps/tools/modules/init/profile.sh || return
fi
module use /home/bingxing2/apps/modules || return
module purge || return
module load compilers/gcc/13.2.0 cmake/3.31.6 \
    hpcx/hpcx-v2.50-gcc-doca_ofed-kylin10-cuda12-aarch64/hpcx || return
export CUDA_HOME="$HOME/.local/opt/dndsr/cuda-12.9.1"
export CUDA_PATH="$CUDA_HOME"
export NCCL_ROOT="$HOME/.local/opt/dndsr/nccl-2.32.6-cuda12.9"
export LD_LIBRARY_PATH="$CUDA_HOME/lib:$NCCL_ROOT/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export OMPI_CC="$(command -v gcc)" OMPI_CXX="$(command -v g++)"
export CC=mpicc CXX=mpicxx
export JOBS="${JOBS:-16}"
export DNDS_CUDA_ARCHITECTURES='80'
export PATH="$CUDA_HOME/bin:$HOME/.pixi/bin:$HOME/.local/bin:$PATH"
alias sq="squeue -o \"%.12i %.9P %.80j %.8u %.2t %.10M %.6D %R\""
