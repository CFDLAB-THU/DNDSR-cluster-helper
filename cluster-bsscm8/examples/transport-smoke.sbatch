#!/usr/bin/env bash
# Compile mpi-pingpong.c on the login node, then export MPI_PROBE and submit.
#SBATCH --job-name=dndsr-transport-smoke
#SBATCH --partition=amd_m8_768
#SBATCH --nodes=2
#SBATCH --ntasks=2
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=1G
#SBATCH --time=00:05:00
#SBATCH --output=logs/transport-smoke-%j.out
#SBATCH --error=logs/transport-smoke-%j.err

set -euo pipefail
: "${MODULE_ENV:?Export the absolute modules.sh path}"
: "${MPI_PROBE:?Compile mpi-pingpong.c and export its absolute executable path}"
source "$MODULE_ENV"
[[ -x "$MPI_PROBE" ]]
export OMP_NUM_THREADS=1 UCX_LOG_LEVEL=info UCX_PROTO_INFO=y
module list 2>&1
srun --ntasks=2 --ntasks-per-node=1 bash -c \
    'hostname; lspci -nn 2>/dev/null | grep -Ei "ethernet|infiniband|network" || true'
srun --ntasks=2 --ntasks-per-node=1 bash -c \
    'hostname; ibv_devinfo 2>/dev/null | grep -E \
    "hca_id:|transport:|fw_ver:|port:|state:|active_mtu:|link_layer:" || true'
ucx_info -v 2>/dev/null || true
ucx_info -d 2>/dev/null | grep -E \
    'Transport:|Device:|Device Type:|System device:' || true
mpirun -np 2 --map-by ppr:1:node --display-map --report-bindings \
    --mca pml_base_verbose 50 "$MPI_PROBE"
