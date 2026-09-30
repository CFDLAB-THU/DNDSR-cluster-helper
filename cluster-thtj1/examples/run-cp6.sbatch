#!/usr/bin/env bash
# Generic one-node, pure-MPI DNDSR production example for thtj1.
# Create logs/ in RUN_DIR before calling sbatch because Slurm opens output first.
#SBATCH --job-name=dndsr-example
#SBATCH --partition=cp6
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=56
#SBATCH --cpus-per-task=1
#SBATCH --time=24:00:00
#SBATCH --output=logs/%x-%j.out
#SBATCH --error=logs/%x-%j.err

set -euo pipefail

: "${EXECUTABLE:?Export the absolute DNDSR executable path}"
: "${CONFIG:?Export the absolute input/config path}"
: "${RUN_DIR:?Export the absolute run directory}"
: "${COMM_ENV:?Export the absolute path of env/ucx-glex.sh}"

[[ -x "$EXECUTABLE" ]] || { echo "not executable: $EXECUTABLE" >&2; exit 2; }
[[ -f "$CONFIG" ]] || { echo "missing config: $CONFIG" >&2; exit 2; }
[[ -d "$RUN_DIR" ]] || { echo "missing run directory: $RUN_DIR" >&2; exit 2; }
[[ -f "$COMM_ENV" ]] || { echo "missing communication environment: $COMM_ENV" >&2; exit 2; }

source "$COMM_ENV"
export OMP_NUM_THREADS="${SLURM_CPUS_PER_TASK:-1}"
export DNDS_DISABLE_ASYNC_MPI=1

cd "$RUN_DIR"

echo "job_id=$SLURM_JOB_ID"
echo "host=$(hostname) node_list=$SLURM_JOB_NODELIST"
echo "nodes=$SLURM_NNODES tasks=$SLURM_NTASKS cpus_per_task=$SLURM_CPUS_PER_TASK omp_threads=$OMP_NUM_THREADS"
echo "executable=$EXECUTABLE"
echo "config=$CONFIG"
echo "run_dir=$RUN_DIR"
echo "source_commit=${SOURCE_COMMIT:-unknown}"
echo "executable_sha256=$(sha256sum "$EXECUTABLE" | awk '{print $1}')"
echo "config_sha256=$(sha256sum "$CONFIG" | awk '{print $1}')"

mpirun -np "$SLURM_NTASKS" "$EXECUTABLE" "$CONFIG"
