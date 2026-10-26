# A8 alternate-login target

Live compute inspection: **2026-10-26**, normal `amd_a8_384` partition.

## CPU and topology

The allocated node reports two AMD EPYC 9554 sockets (Genoa, Zen 4), 64 cores
per socket, one thread per core, 128 physical CPUs, and two NUMA nodes. CPU
family/model/stepping are 25/17/1. Each socket's 64 cores occupy one NUMA node.
ISA flags include AVX2, AVX-512F/DQ/CD/BW/VL, VNNI and BF16. Per-instance
cache values are 32 KiB L1d, 32 KiB L1i, 1 MiB L2 and 32 MiB L3.
The site's older `lscpu` does not support `-C`; cache information was obtained
from its normal output and CPU/cache topology from `lscpu -e` instead.

## Network and MPI

The hardware probe exposes ConnectX-4 InfiniBand. UCX reports version 1.14.0.
A two-node, two-rank C ping-pong transferred 2 MiB and completed with Slurm
exit `0:0`. Each rank reported size two on a distinct node. Verbose runtime
output showed PML UCX and an inter-node endpoint using `rc_mlx5` on `mlx5_0`
port one, with TCP also present in its configuration. Installed transport
components are distinct from this observed runtime selection.

A same-node two-rank 2 MiB ping-pong also completed `0:0` in an exclusive
one-node allocation. Its endpoint used SysV/KNEM shared memory, with `rc_mlx5`
also listed. An earlier small shared-node allocation stalled in UCX
`ibv_reg_mr` / `ud_recv_skb` initialization and was cancelled by the setup
operator. Its locked-memory limit was unlimited and the node reported ample
free host memory; the exact registration failure was not established. The
retry changed both node and allocation shape, so it does not isolate a cause.
Preserve this failed probe separately from the passed validation.

The fixed module file selects Open MPI 4.1.6 with AOCC 5 as its module
dependency, then loads GCC 14.2 last and explicitly overrides the MPI C/C++
wrapper compilers to GCC/G++. MPI C and C++ compile/link guards passed, and
the C++ executable resolves GCC 14's `libstdc++` and the selected MPI libraries.
Default GCC target/tuning are `x86-64`/`generic`; system assembler is 2.30.

## Scheduler and remaining evidence

See [README.md](README.md) for the separate login's QoS/association limits and
SSH method. Hardware and launch observations here are fresh under this login.
Dependency-build and C++ CTest validation are recorded there: externals,
`eulerEX`, and all 99 C++ entries passed, with the source-specific build
workarounds and separate failed Python tooling check reported explicitly.
