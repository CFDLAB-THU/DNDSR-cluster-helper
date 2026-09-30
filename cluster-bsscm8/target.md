# `bsscm8` target description

Live evidence was collected on **2026-09-30**. Raw node names, addresses,
fabric identifiers, job IDs, and full command output remain in the private run
record.

## Compute target

The active compute target is x86-64, with two AMD EPYC 9654 sockets (Genoa,
Zen 4), 96 physical cores per socket, one hardware thread per core, and 192
scheduled CPUs per node. `lscpu` reported AMD family 25, model 17, stepping 1,
two NUMA nodes, and one socket wholly contained in each NUMA node. The reported
per-instance caches were 32 KiB L1 data, 32 KiB L1 instruction, 1 MiB L2, and
32 MiB L3. Slurm exposed 750 GiB of configured memory per node.

The compute-node flags include AVX2, AVX-512F/DQ/CD/BW/VL, AVX-512 VNNI,
AVX-512 BF16, and related Zen 4 features. The approved GCC module nevertheless
defaults to `-march=x86-64 -mtune=generic`; optimized builds can override those
flags only after checking assembler support and the target partition.

## Network and selected MPI transport

Two allocated nodes each exposed a Mellanox MT27700 ConnectX-4 InfiniBand
controller and Intel I350 Gigabit Ethernet controllers. The InfiniBand device
was `mlx5_0`, port 1, active with a 4096-byte active MTU. Firmware revisions
differed between the two sampled nodes, so firmware uniformity must not be
assumed.

System UCX 1.14.0 was built with verbs, RDMA CM, mlx5, KNEM, XPMEM, CMA, and
CUDA support. Visible transports included `rc_mlx5`, `dc_mlx5`, verbs, TCP,
KNEM, SysV, POSIX, CMA, and XPMEM. The selected MPI module exports
`UCX_TLS=^xpmem`, explicitly excluding XPMEM.

Open MPI 4.1.0 was configured with PMIx and Slurm and built with GCC 14.2.0.
Installed PML components include `ucx`, `ob1`, and `cm`; installed BTLs include
`openib`, `tcp`, `vader`, and `self`. Availability alone is not the runtime
choice. Verbose allocations showed that Open MPI selected **PML UCX** over
OB1. A two-rank same-node transfer selected SysV plus KNEM shared-memory paths
(with `rc_mlx5` also in the endpoint configuration). A two-node 2 MiB
ping-pong selected `rc_mlx5` on the InfiniBand device, with TCP over the
Ethernet interface available as fallback. Both probes completed with zero
Slurm exit status.

## Scheduler and launcher

Slurm 23.11.9 exposed `amd_m8_768` as the dated default partition. The working
launcher pattern is an explicit finite `sbatch` allocation followed by
`mpirun`; module loading, wrappers, shared libraries, rank count, and unique
rank identity are checked inside the allocation. The C++ suite uses eight
allocated tasks because its registered tests include up to eight MPI ranks.

## Toolchain and setup result

The exact approved module triple, compiler-target rationale, installed tool
versions, login-node build policy, executable hash, and 88/88 C++ test result
are recorded in [README.md](README.md). Reusable module, build, MPI, transport,
and CTest files live in `env/` and `examples/`.
