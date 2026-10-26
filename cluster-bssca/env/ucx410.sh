#!/usr/bin/env bash
# Scoped 4.1.0-para/UCX environment, validated for startup on 2026-10-23.
# Configure a separate build with -DDNDS_ALLOW_OPENMPI_410=ON explicitly.
if ! type module >/dev/null 2>&1; then
    echo "Initialize the cluster module command before sourcing this file" >&2
    return 2 2>/dev/null || exit 2
fi

_bssca_load_ucx410_modules()
{
    local restore_nounset=0 rc=0
    [[ $- == *u* ]] && restore_nounset=1
    set +u
    module purge && module load cmake/3.24.1 gcc/12.2 OpenBLAS/0.3.7-wxl-public4 || rc=$?
    (( restore_nounset == 0 )) || set -u
    return "$rc"
}
_bssca_load_ucx410_modules || { return 2 2>/dev/null || exit 2; }
unset -f _bssca_load_ucx410_modules

export BSSCA_MPI_ROOT=/public4/soft/openmpi/4.1.0-para
export PATH="$BSSCA_MPI_ROOT/bin:/public4/soft/gcc/12.2/bin:$PATH"
export LD_LIBRARY_PATH="$BSSCA_MPI_ROOT/lib:/public4/soft/gcc/12.2/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export OMPI_MCA_mca_base_component_path="$BSSCA_MPI_ROOT/lib/openmpi"
export OMPI_MCA_pml=ucx
export OMPI_MCA_btl=self,vader
unset OMPI_MCA_btl_openib_allow_ib OMPI_MCA_btl_openib_if_include
unset OMPI_MCA_btl_tcp_if_include OMPI_MCA_coll_tuned_allgather_algorithm
unset OMPI_MCA_coll_tuned_alltoallv_algorithm OMPI_MCA_coll_tuned_use_dynamic_rules
export UCX_TLS=ud_verbs,sm,self
export UCX_NET_DEVICES="${BSSCA_UCX_NET_DEVICES:-all}"
export UCX_LOG_LEVEL=warn

export DNDS_ARRAY_STRATEGY_USE_IN_SITU=0
export DNDS_USE_STRONG_SYNC_WAIT=0
export OMP_NUM_THREADS="${SLURM_CPUS_PER_TASK:-1}"
export OPENBLAS_NUM_THREADS=1
