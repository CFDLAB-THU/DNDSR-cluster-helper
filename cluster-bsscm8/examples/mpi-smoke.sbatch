#!/usr/bin/env bash
#SBATCH --job-name=dndsr-mpi-smoke
#SBATCH --partition=amd_m8_768
#SBATCH --nodes=1
#SBATCH --ntasks=2
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=4G
#SBATCH --time=00:05:00
#SBATCH --output=logs/mpi-smoke-%j.out
#SBATCH --error=logs/mpi-smoke-%j.err

set -euo pipefail
: "${MODULE_ENV:?Export the absolute modules.sh path}"
source "$MODULE_ENV"
export OMP_NUM_THREADS=1
module list 2>&1
command -v gcc mpicc mpirun
mpicc --showme:version
[[ "$(mpicc --showme:command)" == gcc ]]
echo "job_id=$SLURM_JOB_ID nodes=$SLURM_JOB_NODELIST tasks=$SLURM_NTASKS"
echo "cpu_model=$(lscpu | sed -n 's/^Model name:[[:space:]]*//p' | head -n1)"
echo "cpu_arch=$(lscpu | sed -n 's/^Architecture:[[:space:]]*//p' | head -n1)"
echo "cpu_flags=$(lscpu | sed -n 's/^Flags:[[:space:]]*//p' | head -n1)"
mpirun -np "$SLURM_NTASKS" bash -lc \
    'printf "rank=%s size=%s host=%s\n" "$OMPI_COMM_WORLD_RANK" "$OMPI_COMM_WORLD_SIZE" "$(hostname)"'
