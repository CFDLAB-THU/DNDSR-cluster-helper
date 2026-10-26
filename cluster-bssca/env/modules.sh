#!/usr/bin/env bash
# Historical build toolchain from 2026-10-22; its OpenIB runtime failed at scale.
# For the checked UCX runtime experiment, use ucx314.sh and read README.md.
# Source this in a shell with the cluster's environment-modules initialization.
if ! type module >/dev/null 2>&1; then
    echo "Initialize the cluster module command before sourcing this file" >&2
    return 2 2>/dev/null || exit 2
fi

module load cmake/3.24.1 gcc/12.2 OpenBLAS/0.3.7-wxl-public4
module load mpi/openmpi/4.1.2-gcc12.2

# The old custom 4.1.0 installation can otherwise precede the module in PATH.
export BSSCA_MPI_ROOT=/public4/soft/openmpi/openmpi-4.1.2/install
export PATH="$BSSCA_MPI_ROOT/bin:$PATH"
export LD_LIBRARY_PATH="$BSSCA_MPI_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# This package has no UCX PML and disables InfiniBand in openib by default.
# Use the installed verbs transport on the observed mlx4 InfiniBand fabric.
export OMPI_MCA_pml=ob1
export OMPI_MCA_btl=self,vader,openib
export OMPI_MCA_btl_openib_allow_ib=1

# Inherited from the existing single-threaded cluster launcher.
export DNDS_ARRAY_STRATEGY_USE_IN_SITU=0
export DNDS_USE_STRONG_SYNC_WAIT=0
export OMP_NUM_THREADS="${SLURM_CPUS_PER_TASK:-1}"
export OPENBLAS_NUM_THREADS=1
