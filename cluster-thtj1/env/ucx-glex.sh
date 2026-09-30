#!/usr/bin/env bash
# Communication settings observed to work on thtj1 with Open MPI over UCX/GLEX.
# Source this after the compiler and MPI environment has been established.

export UCX_TLS=posix,knem,glex
export UCX_PROTO_ENABLE=n
export UCX_GLEX_ER_MAX_CHANNELS=128
export UCX_GLEX_EP_HC_MR=y
export UCX_GLEX_EP_HC_MPQ=y
export UCX_GLEX_EP_HC_EQ=y
export UCX_GLEX_ERQ_SIZE=2m
export UCX_GLEX_ZC_REQ_CAPACITY=4096
export UCX_RNDV_PUT_FORCE_FLUSH=y
export UCX_RNDV_SCHEME=get_zcopy

export GLEX_EP_TYPE=1
export GLEX_USE_ZC_RNDV=1
export GLEX_BYPASS_ER=0
export GLEX_EP_MEM_SIZE=0x8000000
export GLEX_EAGER_MAX_MSG_SIZE=32768
export GLEX_EP_HC_MR=1
export GLEX_EP_HC_EQ=1
export GLEX_EP_HC_MPQ=1
export GLEX_MAX_ER_CHANNELS=128

export OMPI_MCA_pml=ucx
export OMPI_MCA_pml_ucx_tls=any
export OMPI_MCA_pml_ucx_devices=any
