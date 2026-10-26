#!/usr/bin/env bash
# Revalidated M8 stack for the separate login, 2026-10-26.
source /publicfs01/fs1-share/soft/share-soft/modules/module.sh
module purge
module load cmake/4.1.1
module load mpi/openmpi/5.0.10-gcc14.2.0-share
export OMPI_CC=gcc OMPI_CXX=g++
export OMPI_MCA_pml=ucx UCX_TLS='^xpmem'
export PATH="$HOME/.pixi/bin:$HOME/.local/bin:$PATH"
alias sq="squeue -o \"%.12i %.9P %.80j %.8u %.2t %.10M %.6D %R\""
