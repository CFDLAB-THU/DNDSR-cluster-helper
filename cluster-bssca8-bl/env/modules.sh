#!/usr/bin/env bash
# Same A8 platform, separate login; reviewed 2026-10-26.
source /publicfs01/fs1-share/soft/amd-soft/modules/module.sh
module purge
module load cmake/4.1.1
module load mpi/openmpi/4.1.6-aocc5.0.0
# Load GCC last to retain its C++ runtime and select it for fresh MPI builds.
module load gcc/14.2.0
export OMPI_CC=gcc OMPI_CXX=g++
export OMPI_MCA_pml=ucx UCX_TLS='^xpmem'
export PATH="$HOME/.pixi/bin:$HOME/.local/bin:$PATH"
alias sq="squeue -o \"%.12i %.9P %.80j %.8u %.2t %.10M %.6D %R\""
