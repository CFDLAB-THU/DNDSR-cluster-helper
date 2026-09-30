# `bsscm9` target description

Live evidence was collected on **2026-09-30**. Raw node names, addresses,
fabric identifiers, job IDs, and full output remain in the private run record.

## Compute target

The active target is x86-64, with two AMD EPYC 9755 sockets (Turin, Zen 5), 128
physical cores per socket, one hardware thread per core, and 256 scheduled CPUs
per node. `lscpu` reported AMD family 26, model 2, stepping 1, two NUMA nodes,
and one socket wholly contained in each NUMA node. Per-instance caches were
48 KiB L1 data, 32 KiB L1 instruction, 1 MiB L2, and 32 MiB L3. NUMA distance
was 10 locally and 32 across sockets. Slurm exposed 768 GB configured memory
per node.

The compute flags include AVX2, AVX-512F/DQ/CD/BW/VL, AVX-512 VNNI/BF16/VBMI,
AVX-VNNI, and AVX-512 VP2INTERSECT. GCC 14.2 defaults to
`-march=znver5 -mtune=znver5`. The Intel login node is only the compilation
host and must never supply `-march=native` for compute binaries.

## Network and selected MPI transport

Two allocated nodes each exposed a Mellanox MT27700 ConnectX-4 InfiniBand
controller and Intel I350 Gigabit Ethernet controllers. The InfiniBand device
was `mlx5_0`, port 1, active with a 4096-byte active MTU.

System UCX 1.18.0 was built with verbs, mlx5, RDMA CM, KNEM, XPMEM, CMA, and
CUDA support. Visible transports included `rc_mlx5`, `dc_mlx5`, verbs, TCP,
KNEM, SysV, POSIX, CMA, and XPMEM. The cluster environment exports
`UCX_TLS=^xpmem`, excluding XPMEM.

Open MPI 4.1.8 was built with GCC 14.2.0. Installed PML components include
`ucx`, `ob1`, `cm`, `v`, and `monitoring`; installed BTLs include `openib`,
`tcp`, `vader`, and `self`. Runtime evidence showed Open MPI selecting **PML
UCX** over OB1. A two-rank same-node transfer selected SysV plus KNEM, with
`rc_mlx5` also present in the endpoint configuration. A two-node 2 MiB
ping-pong selected `rc_mlx5` exclusively for the inter-node endpoint. Both
probes completed successfully.

## Scheduler and launcher

At inspection time, `amd_m9_768` exposed 558 nodes and was the default active
partition. The working pattern is a finite `sbatch` allocation followed by
`mpirun`; jobs source the fixed module layer and verify `as`, `ld`, compiler
target flags, MPI wrappers, and rank identity inside the allocation. The C++
suite requests eight tasks because registered tests include up to eight ranks.

## Toolchain and setup result

The approved modules, assembler/linker compatibility shim, tool versions,
login-node build policy, executable hash, and C++ test result are recorded in
[README.md](README.md). Reusable module, assembler, build, MPI, transport, and
CTest files live in `env/` and `examples/`.
