#!/usr/bin/env bash
# Allocation-free, read-only profile refresh for thtj1.
set -euo pipefail

echo "host=$(hostname)"
echo "date=$(date --iso-8601=seconds)"
echo "slurm=$(sinfo --version)"

echo "partitions:"
sinfo -h -o '%P|state=%a|max_time=%l|nodes=%D|cpus=%c|memory_mb=%m|gres=%G'

echo "toolchain:"
gcc --version | sed -n '1p'
g++ --version | sed -n '1p'
cmake --version | sed -n '1p'

echo "mpi:"
command -v mpicc
mpicc --showme:version 2>/dev/null || mpicc -show 2>/dev/null || true
command -v mpirun
mpirun --version | sed -n '1,2p'

if type module >/dev/null 2>&1; then
    echo "loaded modules:"
    module list 2>&1 || true
fi
