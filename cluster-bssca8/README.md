# `bssca8` cluster profile

Last live inspection: **2026-09-30**.

Private home paths, Linux account names, source-fork identity, proxy ports,
node names, and job IDs are deliberately absent from this profile.

## Reviewed toolchain choice

| Component | Selected module | Live evidence |
|---|---|---|
| CMake | `cmake/4.1.1` | CMake 4.1.1 |
| GCC | `gcc/14.2.0` | GCC and G++ 14.2.0 |
| MPI | `mpi/openmpi/4.1.0-gcc14.2.0` | Open MPI 4.1.0; wrappers use GCC 14.2.0 |

The module initialization file purges inherited modules before loading this
fixed triple and defines the standard `sq` queue alias. The interactive Bash
startup sources it. Pixi 0.81.0, uv 0.12.21, Ninja 1.13.2, Doxygen 1.18.0,
and uv-managed Python 3.12.14 were verified during setup.

The compute-node probe reported an AMD EPYC 9554 64-Core Processor (Genoa,
Zen 4). GCC defaults to a portable `x86-64` target with this module. A later
optimized build may set explicit `-march` and `-mtune` after checking both the
compute target and generated assembly with the selected assembler. Do not use
the Intel login node's `-march=native` as a compute target.

Detailed compute topology, network hardware, UCX capabilities, MPI components,
and the transports selected in same-node and cross-node transfers are recorded
in [target.md](target.md).

## Scheduler and build

Slurm reported `amd_a8_384` active with 128 scheduled CPUs per node, 384 GB of
configured memory per node, a 3,000 MB default per CPU, a 3,072 MB maximum per
CPU, and no partition-level wall-time maximum. These are dated observations.
Compilation defaults to the login node with `JOBS=32`; runtime checks use
finite Slurm allocations.

The setup used a fresh Ninja build, populated the external dependencies and
initial CI mesh data, and built `eulerEX` and all C++ unit-test targets. DNDSR's
Python package and pybind modules were not installed or built during cluster
setup. The source tree remained clean at the reviewed detached commit.

The final compute validation completed successfully on 2026-09-30. Same-node
and cross-node two-rank MPI transfers passed, with two distinct ranks and a
zero Slurm exit status. The C++ CTest allocation also completed with zero exit
status: **88 of 88 tests passed** in 325.01 seconds, including registered one-,
two-, four-, and eight-rank MPI cases. The built `eulerEX` executable had
SHA-256 `bf9577e94a29d9cb9143dab08e50cff6c5494d28a50dbd56bd99222b46f431c9`.

Reusable commands live under `examples/`. Copy them into a private run record,
substitute the actual `~/<name>/DNDSR` path, and preserve logs, job IDs,
accounting, source commit, and executable hashes there.
