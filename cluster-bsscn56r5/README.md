# `bsscn56r5` CUDA build profile

Inspected 2026-11-23. Use `ssh bsscn56r5` with the operator's SSH configuration.
The public gateway is `ssh.cn-zhongwei-1.paracloud.com` on port 22. Login,
identity and proxy endpoint details are private. The tested alias connects
directly to the gateway, with SSH agent forwarding disabled and a 45-second
keepalive interval (four missed replies). Use a cluster-provided proxy
or a local SSH `-R` forwarded proxy for downloads. See the
[connection-scoped rule](../SSH_PROXY_FORWARDING.md).

## Scheduler snapshot

Controller inventory checked 2026-11-25 on Slurm 24.11.6.
Public partitions are `gpu_4090` (39 nodes, 312
GPU GRES) and `gpu_5090` (35 nodes, 280 GPU GRES), and separately
account-restricted `hp_4090` and `hp_5090` contain the public nodes, with
three additional nodes in `hp_5090`. The partition QoS `gpu` lists a
one-node cap. The job QoS `gpugpu` has `OverPartQOS` and sets an
eight-node cap when requested.

The user association permits `normal` and `gpugpu` with no explicit default
QoS, an aggregate eight-GPU cap and at most 16 submitted jobs. Accounting
enforces association, limit and QoS constraints. Parent associations were
not visible. Recheck live capacity before planning a job.
Slurm accounts resources with `CR_CPU_MEMORY`. The public
partitions advertise unlimited wall time and the visible QoS entries have
no separate wall-time cap.
The controller uses backfill and sets `PrivateData=jobs,reservations,usage`.
`squeue --start -u "$USER"` can estimate starts for the login's pending jobs.
Use `scontrol show node` for current node state when the site `sinfo` summary
has only a header.

Slurm reports eight GPUs per full node. The RTX 4090 nodes advertise
515,000 MB and 48 or 96 CPUs, depending on SMT. The RTX 5090 partition
advertises 128 CPUs, two sockets, two threads per core and 1,030,000 MB
per node. The x86-64 login is AMD EPYC 7402, with two 24-core sockets, two
threads per core and eight NUMA nodes. The login exposes two 25 Gb/s
ConnectX-5 Ethernet links in an LACP bond, with RoCE v2 GIDs on the bonded
RDMA device. Compute CPU models and compute-node fabric remain unverified.

## Toolchain

GCC 14.2.0, CMake 4.2.0, CUDA 13.0 (nvcc 13.0.48), NCCL 2.28.9, and
NVHPC 25.11 HPC-X 2.25.1 with Open MPI `4.1.9a1` and UCX 1.20.0, all
from site modules. The HPC-X wrapper defaults to NVHPC compilers. The fixed
environment explicitly selects GCC for both wrappers. Disposable CUDA/MPI/NCCL
compile/link checks passed on the x86-64 login for `sm_89` (RTX 4090) and
`sm_120` (RTX 5090).
The login has glibc 2.35 and GNU assembler 2.38. GCC defaults to
`-march=x86-64 -mtune=generic`. The Open MPI build advertises CUDA support
and provides UCX and OB1 PMLs, with Vader and SMCUDA BTL components.
The selected runtime transport requires allocation evidence.

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

Apply the [CUDA include-list patch](../setup/examples/dndsr-cuda-include-list.patch)
to this source revision before configuring. CMake 4.2 reports the CUDA 13
and CCCL include directories as a list. This revision needs a separate
compiler flag for each element.

The login reported a 1 GiB quota and initial header extraction in the home
checkout hit `Disk quota exceeded`. The operator moved the workspace under
the site's shared `~/run` mount and linked the canonical workspace name to
it. Build trees and installed externals belong on that mount. The temporary
login-local scratch build was stopped after the shared path was verified.
The selected profile defaults to eight build workers after repeated
interruptions at 16.

A login-side trace captured SIGTERM to Ninja from a process with UID 0.
The source service and reason remain unconfirmed. At eight workers, the
build finished the independent files and retried the interrupted objects
in place. The initial revision then linked `build-cauchy-cuda/app/cauchy.exe`.
`cuobjdump` reported native `sm_89` and `sm_120` images. The selected
Open MPI, NCCL 2.28.9, and CUDA 13.0 runtime libraries resolved. The
initial executable SHA-256 is
`78b0c27a78528bb4c190891c288680ef2f341c5961f743a07dec1ebb90d0322c`.

The refreshed executable linked at eight workers, with the same native
`sm_89` and `sm_120` images and library resolution. `libcuda.so.1` is
supplied by the compute driver and was absent on the login. The refreshed
executable SHA-256 is
`9c17e6b02d0b6de12ac3fab2a277baa059c5cdf74cd82fecd98c944d8ac70e7c`.

No scheduler job or GPU program was run for this setup. Compute driver
compatibility, CUDA-aware transfers and NCCL collectives require runtime
evidence.
