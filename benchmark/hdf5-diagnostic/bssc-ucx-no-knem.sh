#!/usr/bin/env bash
# Diagnostic UCX policy for the BSSC large-rank HDF5 retry.
# Keep the selected UCX PML and InfiniBand path while excluding both XPMEM and
# KNEM from intra-node communication. Error handlers remain enabled so a
# low-level signal has a chance to leave a backtrace in the Slurm log.
export OMPI_MCA_pml=ucx
export UCX_TLS='^xpmem,knem'
export UCX_HANDLE_ERRORS=bt
export OMPI_MCA_orte_base_help_aggregate=0
export OMPI_MCA_opal_abort_print_stack=1
