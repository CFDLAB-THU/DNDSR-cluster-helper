# `bsscm8` cluster profile

Last live inspection: **2026-09-30**.

Private home paths, Linux account names, source-fork identity, and proxy ports
are deliberately absent from this profile.

## Reviewed toolchain choice

| Component | Selected module | Live evidence |
|---|---|---|
| CMake | `cmake/4.1.1` | `cmake 4.1.1` |
| GCC | `gcc/14.2.0-a8-m8` | GCC and G++ 14.2.0; generic x86-64 default |
| MPI | `mpi/openmpi/4.1.0-gcc14.2.0-a8-m8` | Open MPI 4.1.0; wrappers use GCC 14.2.0 |

The module initialization file purges inherited modules before loading this
fixed triple and defines the standard `sq` queue alias. The interactive Bash
startup sources it. Pixi, uv, Ninja 1.13.2, and uv-managed Python 3.12 were
verified during setup.

An initial scheduled build with the `-share` GCC/Open MPI pair exposed a
toolchain packaging mismatch: GCC defaulted to `-march=znver5`, but resolved
`as` to system binutils 2.30, which rejected its AVX-VNNI assembly. The matching
`-a8-m8` pair defaults to generic `x86-64` and compiles successfully with that
assembler.

The compute-node probe reported an AMD EPYC 9654 96-Core Processor with Zen 4
ISA features. The portable compiler target is intentional for initial
validation. A later optimized build may use explicit `-march` and `-mtune` only
after checking generated assembly against the selected assembler. Never use
login-node `-march=native` as a proxy for compute-node capability.

Detailed compute topology, network hardware, UCX capabilities, installed MPI
components, and the transport selected in same-node and cross-node transfers
are recorded in [target.md](target.md).

## Scheduler and build

Slurm 23.11.9 reported `amd_m8_768` as the default active partition, with
4,000 MB default memory per CPU and no partition-level wall-time maximum. These
are dated observations. Compilation defaults to the login node with `JOBS=32`.
Runtime smoke and C++ tests use finite Slurm allocations with no hard-coded
account or QoS.

This host's established `build/` uses Unix Makefiles and remains unchanged;
fresh build trees use Ninja. The setup built the external libraries,
`eulerEX`, and `all_unit_tests`. Python dependencies were installed in the uv
venv, but DNDSR's pybind modules and Python tests are outside this setup phase.

The final compute-node validation completed successfully on 2026-09-30. A
two-rank MPI smoke reported two distinct ranks on one allocated compute node,
and Slurm recorded a zero exit status. The C++ CTest allocation likewise
finished with a zero exit status: **88 of 88 tests passed** in 365.60 seconds,
including the registered one-, two-, four-, and eight-rank MPI cases. The built
`eulerEX` executable had SHA-256
`49750eefc3b481b9695ffca934e35f76d71a0b93a9734af6d0dd7e38c0f1bf0a`.

Initial meshes come from the repository referenced by the current DNDSR CI
workflow. Its private execution URL is not duplicated here.

Reusable commands live under `examples/`. Copy them into a private run record,
substitute the actual `~/<name>/DNDSR` path, and preserve logs, job IDs,
accounting, source commit, and executable hashes there.
