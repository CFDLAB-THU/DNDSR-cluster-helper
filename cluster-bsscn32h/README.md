# `bsscn32h` CUDA build profile

Inspected 2026-11-23. Use `ssh bsscn32h` with the operator's SSH configuration.
The public gateway is `ssh.cn-zhongwei-1.paracloud.com` on port 22. Login,
identity and proxy endpoint details are private. The tested alias connects
directly to the gateway, with SSH agent forwarding disabled and a 45-second
keepalive interval (four missed replies). Use a cluster-provided proxy
or a local SSH `-R` forwarded proxy for downloads. See the
[connection-scoped rule](../SSH_PROXY_FORWARDING.md).

## Scheduler snapshot

Controller inventory checked 2026-11-25 on Slurm 22.05.8. `gpu` is the
default partition with 174 nodes and 696 GPU GRES. All eight `gpu_mem`
nodes (32 GPU GRES) are also in `gpu`. `gpu_mig` (240 slices) requires
a separate account and QoS. Controller nodes advertise
four GPUs per full node, 128 CPUs and 260,000 MB or 520,000 MB RAM.
The site exposes an A100 MIG label. The compile profile targets Ampere
`sm_80`; generic GRES labels do not identify every full-card node.
The partition QoS `gpu` lists a one-node cap. The job QoS `gpugpu`
has `OverPartQOS` and sets a 500-node cap when requested. This user
association also caps aggregate CPUs at 256.

The user association permits `normal` and `gpugpu` with no explicit default
QoS, an aggregate eight-GPU cap and at most 16 submitted jobs. Accounting
enforces association, limit and QoS constraints. Parent associations were
not visible. Recheck live capacity before planning a job.
Slurm accounts resources with `CR_CPU_MEMORY`. The public
partitions advertise unlimited wall time and the visible QoS entries have
no separate wall-time cap.
The controller uses backfill and sets `PrivateData=jobs,reservations,usage`.
`squeue --start -u "$USER"` can estimate starts for the login's pending jobs.

Slurm reports AArch64 nodes with four sockets, 32 cores per socket and no
SMT in the full-GPU partitions. The login is a HiSilicon Kunpeng-920 with
two 24-core sockets, one thread per core and two NUMA nodes. Paratera lists
Kunpeng 920 7265 compute nodes, four A100 PCIe 40 GB cards and four 100 Gb/s
RoCE links for both N32HA14P memory tiers. These are vendor specifications.
The login exposes a Virtio NIC. Compute-node network devices and runtime
transport remain unverified. [Paratera compute specifications](https://www.paratera.com/power.html).

## Toolchain

Verified on 2026-11-27. Source [env/modules.sh](env/modules.sh) before configuring, building or launching. N32 uses AArch64, glibc 2.28, GCC 13.2, CMake 3.31.6 and HPC-X 2.50 (Open MPI 5.0.10rc2). Select the **site modules** `compilers/cuda/12.8` (nvcc 12.8.61) and `nccl/2.26.5-1_cuda12.8`. The NCCL library contains SM80 code for A100. The earlier private CUDA 12.9.1 / NCCL 2.32.6 installation was used in an older build. The profile removes its path entries before loading the production stack.

Use AmgX and the parallel scientific libraries built for the selected toolkit and MPI. On a cached build, check `CMAKE_CUDA_COMPILER`, `CUDAToolkit_ROOT`, `DNDS_NCCL_LIBRARY` and `DNDS_NCCL_INCLUDE_DIR`. Check the loaded NCCL path with `ldd` after linking. A tool’s module label and the versions used to compile UCX can differ from the CUDA libraries resolved by the executable.

The profile defaults to 16 build workers. An older interrupted build repeatedly triggered Ninja 1.13.2 dependency-log recovery. When recovering that build, stop concurrent writers, back up `.ninja_deps` and use a Ninja containing the upstream recovery fix to run `-C <build-directory> -t recompact`. [Ninja recovery fix](https://github.com/ninja-build/ninja/pull/2764).

The workstation cross-build produced SM80 LVR device code and relinked an AArch64 solver from the target build objects. The login loader resolved its relocations with the documented driver-stub check. See the [cross-build workflow](../cross-build/README.md) and [native compile-only procedure](../setup/README.md#cuda-build-without-an-allocation).
