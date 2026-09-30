# `cluster-<alias>` target description

Create this description as a required setup outcome. Replace placeholders with
dated, live evidence and keep raw command output in the private run record.
Do not publish node names, addresses, MACs, account names, or personal paths.

## Compute target

- Inspection date and partition:
- CPU vendor, model, architecture, stepping, and microarchitecture:
- `lscpu` topology: sockets, cores per socket, threads per core, NUMA nodes:
- Compute-node ISA flags relevant to compilation:
- Cache hierarchy and NUMA CPU/memory layout:
- Memory per node and scheduler memory accounting:
- Accelerator model/topology, or explicitly none observed:

Record the compute node separately from the login node. Preserve the complete
`lscpu`, `lscpu -e`, `lscpu -C`, `numactl --hardware`, and relevant Slurm node
output privately; publish a sanitized summary here.

## Network and MPI transport

- Network device classes, vendor/model, kernel driver, firmware, and link type:
- InfiniBand/RoCE device, port state, rate, GID/link layer, and MTU when present:
- UCX command/version, compiled transports, visible devices, and relevant
  `UCX_*` environment imposed by the module:
- Selected MPI module, runtime version, configure identity, and compiler wrapper:
- MPI components installed: PML, BTL, MTL, OSC, collective modules:
- Runtime-selected intra-node PML/transport:
- Runtime-selected inter-node PML/transport from a two-node smoke:
- Solver-relevant MPI environment variables and their source:

Installed components only show availability. Record the component actually
selected in verbose MPI runtime output. If UCX is absent, disabled, or bypassed,
say so explicitly. Keep IP addresses, fabric addresses, hostnames, and MACs out
of the public profile.

## Scheduler and launcher

- Scheduler and version:
- Default/intended partitions and dated resource limits:
- Node/task/CPU/memory accounting model:
- Working `sbatch` plus launcher pattern:
- Module propagation and dynamic-library resolution observed inside allocation:

## Toolchain and build

- Exact CMake, GCC, assembler, and MPI module names:
- Resolved executable paths and versions:
- GCC default `-march` and `-mtune`:
- Compile/link smoke results and known packaging limitations:
- Pixi, uv, Python, Ninja, and Doxygen versions:
- DNDSR source/external/mesh revisions, recorded without private remote URLs:
- Build generator, targets, parallelism, executable hash, and C++ test summary:

## Files

List the reusable `env/` and `examples/` files shipped in this cluster profile,
their intended execution location, and the private evidence each one records.
