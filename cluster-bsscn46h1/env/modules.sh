#!/usr/bin/env bash
# Source this file in Bash before configuring or building DNDSR.
source /etc/profile.d/modules.sh || return
module purge || return
module load gcc/14.2.0 cmake/4.2.0 nvhpc/25.11-hpcx-cuda13 \
    cuda/13.0 nccl/2.28_cuda13.0 || return
export NCCL_ROOT=/data/apps/nccl/nccl-2.28.9-1/build
export OMPI_CC="$(command -v gcc)" OMPI_CXX="$(command -v g++)"
export CC=mpicc CXX=mpicxx
export JOBS="${JOBS:-8}"
export DNDS_CUDA_ARCHITECTURES='80;90'
export PATH="$CUDA_HOME/bin:$HOME/.pixi/bin:$HOME/.local/bin:$PATH"
alias sq="squeue -o \"%.12i %.9P %.80j %.8u %.2t %.10M %.6D %R\""
