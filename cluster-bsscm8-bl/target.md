# M8 alternate-login target

Live compute inspection: **2026-10-26**, partition `amd_m8_768`.

## CPU, memory and network

The allocated node reports two AMD EPYC 9654 sockets (Genoa, Zen 4), 96 cores
per socket, one thread per core, 192 physical CPUs and two NUMA nodes. CPU
family/model/stepping are 25/17/1; NUMA CPU groups are 0--95 and 96--191.
Per-instance caches are 32 KiB L1d, 32 KiB L1i, 1 MiB L2 and 32 MiB L3.
The ISA includes AVX2, AVX-512F/DQ/CD/BW/VL, VNNI and BF16. Slurm reports
768,000 MB per node. The complete topology and hardware output remain in
the private record; login-node architecture is not used as the compute target.

Two-node probes expose ConnectX-4 InfiniBand and active `mlx5_0` port one,
MTU 4096. UCX is 1.14.0. The selected module excludes XPMEM.
Visible UCX transports include `rc_mlx5`, `dc_mlx5`, RC/UD verbs, TCP, CMA,
KNEM, POSIX, SysV, self and XPMEM; visibility does not override the exclusion.

## MPI validation

The reviewed runtime is Open MPI 5.0.10 built with GCC 14.2. MPI wrappers
explicitly use GCC/G++. C, C++, MPI C and MPI C++ compile/link checks passed,
including dynamic-library resolution. The current compiler defaults are
`-march=x86-64 -mtune=generic`; this differs from the historical M8 packaging
failure and was verified directly rather than inferred from the module name.

Installed PML components include UCX, OB1, CM, V and monitoring; BTLs include
self, shared memory, TCP and UCT. OSC components include shared memory, RDMA,
UCX and monitoring. Collective modules include basic, tuned, libnbc, han,
hcoll, ftagree and others. No MTL component was listed by the parameter query.
These installed components are availability evidence; the following probes
establish the runtime-selected transport.

Same-node and cross-node two-rank 2 MiB C ping-pong probes completed with
Slurm exit `0:0`. Runtime output selected PML UCX, SysV/KNEM shared-memory
transports for the same-node endpoint and `rc_mlx5` for the cross-node endpoint;
TCP also appeared in the cross-node configuration. Both ranks reported size
two and the expected host placement. A TCP connection-reset diagnostic was
printed during cross-node shutdown after the rank completion markers, despite
the successful exit. Preserve it as an observed warning, not a failed transfer.

## Setup result

See [README.md](README.md) for this login's SSH, QoS, association limits and
completed provisioning result. The externals, `eulerEX` and test executables
built successfully; all 99 selected C++ tests passed on one exclusive M8 node
with exit `0:0`. Revision-specific build-only test workarounds and source,
dependency and executable hashes are recorded there.
