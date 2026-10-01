#!/usr/bin/env bash
# Nodes, tasks per node, partition, output, and error paths are supplied by sbatch.
#SBATCH --exclusive
#SBATCH --cpus-per-task=1
#SBATCH --time=01:00:00

set -euo pipefail
: "${SOURCE_DIR:?absolute reference checkout}"
: "${BUILD_DIR:?absolute build paired with SOURCE_DIR}"
: "${RUN_DIR:?absolute run member directory}"
: "${MESH:?absolute UP3D mesh path}"
: "${MESH_N:?mesh cells per direction}"
: "${TASKS_PER_NODE:?physical cores and MPI ranks per node}"
: "${EXPECTED_COMMIT:?full reference commit}"

if [[ -n "${MODULE_ENV:-}" ]]; then
    source "$MODULE_ENV"
fi
if [[ -n "${COMM_ENV:-}" ]]; then
    source "$COMM_ENV"
fi

export DNDS_DIST_OMP_NUM_THREADS=1
export OMP_NUM_THREADS=1 OMP_DYNAMIC=false
export OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 BLIS_NUM_THREADS=1
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY all_proxy

cd "$SOURCE_DIR"
[[ "$(git rev-parse HEAD)" == "$EXPECTED_COMMIT" ]]
[[ "$(sed -n 's/^CMAKE_HOME_DIRECTORY:INTERNAL=//p' "$BUILD_DIR/CMakeCache.txt")" == "$SOURCE_DIR" ]]
[[ -x "$BUILD_DIR/app/euler3D.exe" && -r "$MESH" ]]
grep -qx 'DNDS_DIST_MT_USE_OMP:BOOL=OFF' "$BUILD_DIR/CMakeCache.txt"
slurm_tasks_per_node="${SLURM_NTASKS_PER_NODE%%(*}"
[[ "$slurm_tasks_per_node" == "$TASKS_PER_NODE" ]]
[[ "$SLURM_NTASKS" == "$((SLURM_NNODES * TASKS_PER_NODE))" ]]

echo "BENCH_META_BEGIN"
printf 'cluster=%s\n' "${CLUSTER_ALIAS:-unknown}"
printf 'job_id=%s nodes=%s ranks=%s tasks_per_node=%s cpus_per_task=%s\n' \
    "$SLURM_JOB_ID" "$SLURM_NNODES" "$SLURM_NTASKS" \
    "$SLURM_NTASKS_PER_NODE" "$SLURM_CPUS_PER_TASK"
printf 'source=%s commit=%s branch=%s\n' "$SOURCE_DIR" \
    "$(git rev-parse HEAD)" "$(git branch --show-current)"
printf 'threading=mpi-only DNDS_DIST_OMP_NUM_THREADS=%s OMP_NUM_THREADS=%s\n' \
    "$DNDS_DIST_OMP_NUM_THREADS" "$OMP_NUM_THREADS"
printf 'dnds_disable_async_mpi=%s\n' "${DNDS_DISABLE_ASYNC_MPI:-0}"
grep -E '^(DNDS_USE_OMP|DNDS_DIST_MT_USE_OMP):BOOL=' "$BUILD_DIR/CMakeCache.txt"
printf 'mesh_n=%s cells=%s cells_per_rank=%.9f\n' "$MESH_N" \
    "$((MESH_N * MESH_N * MESH_N))" \
    "$(awk -v n="$MESH_N" -v r="$SLURM_NTASKS" 'BEGIN {printf "%.9f", n*n*n/r}')"
module list 2>&1 || true
mpicc --showme:version 2>/dev/null || true
sha256sum "$BUILD_DIR/app/euler3D.exe" "$RUN_DIR/euler3D_config_BenchTGV_p3.json" "$MESH"
lscpu | sed -n -e '/^Model name:/p' -e '/^Socket(s):/p' -e '/^Core(s) per socket:/p' -e '/^Thread(s) per core:/p'
echo "BENCH_META_END"

cd "$BUILD_DIR"
mpirun --nooversubscribe --bind-to core \
    --map-by "ppr:${TASKS_PER_NODE}:node:PE=1" \
    -np "$SLURM_NTASKS" \
    "$BUILD_DIR/app/euler3D.exe" "$RUN_DIR/euler3D_config_BenchTGV_p3.json" \
    -k /dataIOControl/meshFile -v "\"$MESH\"" \
    -k /dataIOControl/outPltName -v "\"$RUN_DIR/raw/out\""
