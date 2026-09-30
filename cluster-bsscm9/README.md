# `bsscm9` cluster profile

Last live inspection: **2026-09-30**.

Private home paths, Linux account names, source-fork identity, proxy endpoints,
node names, and job IDs are deliberately absent from this profile.

## Reviewed toolchain choice

| Component | Selected environment | Live evidence |
|---|---|---|
| CMake | `cmake/3.30.2` | CMake 3.30.2 |
| GCC | `gcc/14.2.0` | GCC and G++ 14.2.0; default `znver5` target |
| MPI | `openmpi/4.1.8-gcc14.2.0` | Open MPI 4.1.8; wrappers use GCC 14.2.0 |
| Assembler | GNU `as` 2.46.1, assembler-only shim | accepts Zen 5 instructions |
| Linker | system GNU `ld` 2.30 | links GCC and Open MPI outputs |

The compute target is AMD EPYC 9755 (Turin, Zen 5). The login node is Intel,
so `-march=native` on the login node is incorrect. The selected GCC defaults to
`-march=znver5 -mtune=znver5`; builds nevertheless record and check those values
explicitly before compiling externals and DNDSR.

The GCC module originally resolved GNU `as` 2.30, which cannot assemble all
Zen 5 output. A dedicated Pixi binutils environment supplies GNU `as` 2.46.1,
but only the assembler is exposed through `~/.local/dndsr-znver5-as/bin`.
The full binutils environment must not be prepended to `PATH`: its linker is not
compatible with this system MPI layout. The assembler wrapper also passes
`--compress-debug-sections=none`, because system `ld` 2.30 cannot decode the
new assembler's default compressed DWARF. [env/install-as-wrapper.sh](env/install-as-wrapper.sh)
creates the isolated Pixi environment and installs this guarded shim. Run it in
the foreground proxy shell while network access is available; it never exposes
the replacement environment's linker.

Pixi 0.81.0 supplies Ninja 1.13.2 and Doxygen 1.18.0. uv 0.12.21 installs
Python 3.12.14 and creates the DNDSR venv. DNDSR itself is not installed into
the venv.

## Scheduler and build

Slurm reported `amd_m9_768` as the active default partition, with 256 scheduled
CPUs per node, 768 GB configured memory per node, 2,700 MB default memory per
CPU, 2,764 MB maximum memory per CPU, and no partition-level wall-time maximum.
These are dated observations.

Compilation defaults to the login node with `JOBS=32`,
`CMAKE_BUILD_PARALLEL_LEVEL=32`, `MAKEFLAGS=-j32`, and Ninja. The setup populated
external dependencies and CI mesh data, then built `eulerEX` and all C++ unit
test targets from DNDSR commit
`f6ece7e91e97c6337ef0761c30017b2ddad6b24b`. The build revalidated GCC, MPI,
assembler, linker, target flags,
and worker counts immediately before both external and DNDSR compilation. The
DNDSR executable link uses `-Wl,--exclude-libs,ALL`: DNDSR's Eigen 5 inline
symbols must not interpose on Cantera objects compiled against bundled Eigen
3.4. The reactive test executable was checked to have no dynamic export of the
conflicting `SparseMatrix::resize` symbol.
Python bindings and Python tests were outside setup scope and remain unbuilt.

The built `eulerEX` executable had SHA-256
`3e98a36da1bc3ddae1918896644913b781f995210687fd5100303483463d2211`.
The bounded compute-node CTest run passed all 88 C++ tests, including registered
MPI cases at 1, 2, 4, and 8 ranks. CTest reported 325.43 seconds; Slurm reported
5 minutes 26 seconds and exit status `0:0` for the allocation. No Python test
was run.

Same-node and cross-node two-rank MPI probes completed with zero Slurm exit
status. Open MPI selected PML UCX in both cases. See [target.md](target.md) for
CPU topology, network hardware, UCX capabilities, and selected transports.

Reusable commands live under `env/` and `examples/`. Copy them into a private
run record, substitute the actual `~/<name>/DNDSR` path, and preserve logs,
source commit, accounting, and executable hashes there.
