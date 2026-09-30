#!/usr/bin/env bash
# Run the configured C++ suite, including its registered MPI rank counts.
#SBATCH --job-name=dndsr-ctest
#SBATCH --partition=amd_m9_768
#SBATCH --nodes=1
#SBATCH --ntasks=8
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=2700M
#SBATCH --time=00:30:00
#SBATCH --output=logs/test-%j.out
#SBATCH --error=logs/test-%j.err

set -euo pipefail
: "${SOURCE_DIR:?Export the absolute source directory}"
: "${BUILD_DIR:?Export the matching absolute build directory}"
: "${MODULE_ENV:?Export the absolute modules.sh path}"
source "$MODULE_ENV"
source "$SOURCE_DIR/venv/bin/activate"
module list 2>&1
command -v cmake gcc as ld mpicc mpirun
mpicc --showme:version
[[ "$(mpicc --showme:command)" == gcc ]]
[[ "$(command -v as)" == "$HOME/.local/dndsr-znver5-as/bin/as" ]]
[[ "$(command -v ld)" == /usr/bin/ld ]]
[[ "$(gcc -Q --help=target 2>/dev/null | awk '$1 == "-march=" {print $2}')" == znver5 ]]
[[ "$(gcc -Q --help=target 2>/dev/null | awk '$1 == "-mtune=" {print $2}')" == znver5 ]]
export OMP_NUM_THREADS=1 DNDS_MECH_PATH="$SOURCE_DIR/external/cfd_externals/install/data"
ctest --test-dir "$BUILD_DIR" --output-on-failure -E '^pytest_' -j "${CTEST_JOBS:-1}"
