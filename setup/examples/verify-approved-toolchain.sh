#!/usr/bin/env bash
# Compile-only guard for a module triple already selected by the agent/operator.
set -euo pipefail

: "${MODULE_ENV:?Set MODULE_ENV to the approved modules.sh}"
: "${EXPECTED_GCC_VERSION:?Set the reviewed GCC version prefix}"
: "${EXPECTED_MPI_VERSION:?Set the reviewed Open MPI version prefix}"
source "$MODULE_ENV"

for command_name in cmake gcc g++ as mpicc mpicxx mpirun; do
    command -v "$command_name"
done
gcc_version=$(gcc -dumpfullversion)
mpi_version=$(mpicc --showme:version)
mpi_command=$(mpicc --showme:command)
[[ "$gcc_version" == "$EXPECTED_GCC_VERSION"* ]]
[[ "$mpi_version" == *"Open MPI $EXPECTED_MPI_VERSION"* ]]
[[ "$mpi_command" == gcc ]]

cmake --version | sed -n '1p'
gcc --version | sed -n '1p'
as --version | sed -n '1p'
mpicc --showme:version
mpicc --showme:command
gcc -Q --help=target 2>/dev/null | grep -E '^[[:space:]]+-m(arch|tune)='

scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
cat > "$scratch/plain.c" <<'EOF'
int main(void) { return 0; }
EOF
cat > "$scratch/plain.cpp" <<'EOF'
int main() { return 0; }
EOF
cat > "$scratch/mpi.c" <<'EOF'
#include <mpi.h>
int main(int argc, char **argv)
{
    MPI_Init(&argc, &argv);
    MPI_Finalize();
    return 0;
}
EOF
cp "$scratch/mpi.c" "$scratch/mpi.cpp"
gcc -Wall -Wextra -Werror "$scratch/plain.c" -o "$scratch/plain-c"
g++ -Wall -Wextra -Werror "$scratch/plain.cpp" -o "$scratch/plain-cxx"
mpicc -Wall -Wextra -Werror "$scratch/mpi.c" -o "$scratch/mpi-c"
# Open MPI 4.1 headers can warn in their removed C++ bindings. Keep all other
# warnings fatal while exempting the vendor-header cast warning.
mpicxx -Wall -Wextra -Werror -Wno-error=cast-function-type \
    "$scratch/mpi.cpp" -o "$scratch/mpi-cxx"
file "$scratch/plain-c" "$scratch/plain-cxx" "$scratch/mpi-c" "$scratch/mpi-cxx"
ldd "$scratch/mpi-c" | grep -E 'libmpi|not found'
! ldd "$scratch/mpi-c" | grep -q 'not found'
echo "Compile guards passed. Run the cluster profile's two-rank Slurm smoke next."
