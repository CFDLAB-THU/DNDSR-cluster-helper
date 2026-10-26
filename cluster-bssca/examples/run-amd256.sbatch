#!/usr/bin/env bash
# Materialize a run-specific copy and explicit absolute Slurm log paths.
#SBATCH --job-name=dndsr
#SBATCH --partition=amd_256
#SBATCH --nodes=16
#SBATCH --ntasks-per-node=64
#SBATCH --cpus-per-task=1
#SBATCH --time=7-00:00:00

set -euo pipefail
: "${SOURCE_DIR:?Set the source checkout path}"
: "${EXECUTABLE:?Set the absolute solver executable path}"
: "${CONFIG:?Set the absolute configuration path}"
: "${RUN_DIR:?Set the invocation directory}"
: "${CLUSTER_ENV:?Set the path to the validated runtime environment, e.g. cluster-bssca/env/ucx314.sh}"
source "$CLUSTER_ENV"
[[ -x "$EXECUTABLE" && -f "$CONFIG" && -d "$RUN_DIR" ]] || exit 2
cd "$RUN_DIR"
echo "job=$SLURM_JOB_ID nodes=$SLURM_NNODES ranks=$SLURM_NTASKS omp=$OMP_NUM_THREADS"
git -C "$SOURCE_DIR" rev-parse HEAD
sha256sum "$EXECUTABLE" "$CONFIG"
command -v mpirun mpicxx
mpirun --version
mpicxx --showme:command
ldd "$EXECUTABLE" | grep -E 'libmpi|libopen-rte|libopen-pal'
mpirun --prefix "${BSSCA_MPI_ROOT:?Set the verified MPI prefix}" \
    -np "$SLURM_NTASKS" --bind-to core --map-by ppr:64:node:PE=1 \
    "$EXECUTABLE" "$CONFIG"
