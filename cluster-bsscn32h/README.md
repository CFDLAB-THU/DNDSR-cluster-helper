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

AArch64, glibc 2.28. Site modules supply GCC 13.2.0, CMake 3.31.6,
and HPC-X 2.50 with Open MPI `5.0.10rc2` and UCX 1.21.0. The site CUDA
12.8/NCCL 2.26.5 stack passed a disposable `sm_80` compile/link check.
The approved environment uses NVIDIA CUDA 12.9.1 and NCCL 2.32.6 for CUDA
12.9 in user-local prefixes specified in the module layer. NVIDIA's CUDA
redistribution manifest supplies Linux SBSA components and checksums. NCCL
comes from the NVIDIA RHEL 8 SBSA runtime/devel packages. HPC-X's UCX build
records CUDA 12.9.1. The site CUDA/NCCL 12.8 modules are not loaded into the
selected profile.

The CUDA prefix uses the Linux SBSA archives for nvcc, cudart, CCCL,
cuobjdump, nvdisasm, CUPTI, NVTX, NVRTC, cuBLAS, cuSOLVER, cuSPARSE, and
nvJitLink. Use each entry's `linux-sbsa` URL relative to the manifest's
directory. Verify the published SHA-256 and extract into the CUDA prefix
with `tar --strip-components=1`. Unpack the RHEL 8 SBSA runtime and devel
RPMs for NCCL `2.32.6-1+cuda12.9` with `rpm2cpio` and `cpio` into a
staging directory, then copy the contents of its `usr/` into the NCCL
prefix. Use the paths in `env/modules.sh`. The system driver remains the
site's responsibility. [CUDA 12.9.1 manifest](https://developer.download.nvidia.com/compute/cuda/redist/redistrib_12.9.1.json)
and [NVIDIA NCCL downloads](https://developer.nvidia.com/nccl/nccl-download).

The CUDA archives extract libraries under `lib`. Add `lib64 -> lib` inside
this prefix when `lib64` is absent so nvcc can find its static device/runtime
libraries during CMake compiler identification and device linking. The final
selected stack passed a separate `sm_80` compile/link with NCCL, cuSOLVER and
MPI. The full application build uses the same library layout.
The login uses GNU assembler 2.34. The Open MPI build advertises CUDA
support and provides UCX and OB1 PMLs and a shared-memory BTL. The selected
runtime transport requires allocation evidence.
The selected profile defaults to 16 build workers.

An interrupted build repeatedly triggered Ninja 1.13.2 dependency-log
recovery. The existing log was backed up, then the application build was
resumed using a local Ninja built from upstream merge `def9560`. Select
that executable for this build with `NINJA_PROGRAM`. With the build stopped,
back up `.ninja_deps` before running the repaired Ninja with
`-C <build-directory> -t recompact`. The Pixi global Ninja remains available.
[Upstream Ninja recovery fix](https://github.com/ninja-build/ninja/pull/2764).

Source [env/modules.sh](env/modules.sh) for the reviewed environment.
The login tools are Pixi 0.84.2, uv 0.13.9, Python 3.12.16, Ninja 1.13.2
and Doxygen 1.18.0. The canonical venv is managed by uv.
Use the operator's canonical DNDSR root and the
[compile-only procedure](../setup/README.md#cuda-build-without-an-allocation).
The initial validated source was `71b906bc9915e1da96545dc4d604dc9f2e3042c3`.
The verified refresh is `35913f4fa0d824ff4893c2601190b07d686bac76`.
Both use externals `b61dfc49296b58fed3a6305a52b3e5f8509395e9`. The initial
executable and validation log are preserved under the build directory's
`verified/<revision>/` directory.
HDF5 has parallel I/O enabled. HDF5 and ParMETIS both resolve the same
Open MPI from the selected profile.

The AArch64 login built and linked the initial `build-cauchy-cuda/app/cauchy.exe` with
Ninja, 16 workers on the final attempt, CUDA and NCCL enabled, and both
equation families and dimensions enabled. `cuobjdump` reported a native
`sm_80` image. The executable resolves the selected Open MPI, UCX,
NCCL 2.32.6, CUDA 12.9 and GCC 13.2 runtime libraries. `libcuda.so.1` is
supplied by the compute driver and was absent on the login. The initial executable
SHA-256 is
`b4b3807a851d0649d5a735f2fe5220098c178fb6f28352c669e7f720440ad9d2`.

The refreshed executable linked at 16 workers, with the same native
`sm_80` image and library resolution. Its SHA-256 is
`ae099b79dc993632e6cd40df2771bb2bb3a8a3bcf5daa73720e05fc3de436df2`.

No scheduler job or GPU program was run for this setup. Compute driver
compatibility, CUDA-aware transfers and NCCL collectives require runtime
evidence.
