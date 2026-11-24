# `bsscn46h1` CUDA build profile

Inspected 2026-11-23. Use `ssh bsscn46h1` with the operator's SSH configuration.
The public gateway is `ssh.cn-zhongwei-1.paracloud.com` on port 22. Login,
identity and proxy endpoint details are private. The tested alias connects
directly to the gateway, with SSH agent forwarding disabled and a 45-second
keepalive interval (four missed replies). Use a cluster-provided proxy
or a local SSH `-R` forwarded proxy for downloads. See the
[connection-scoped rule](../SSH_PROXY_FORWARDING.md).

## Scheduler snapshot

Controller inventory checked 2026-11-25 on Slurm 24.11.6.
Public partitions `gpu_a800` (31 nodes, 248 GPU GRES),
`gpu_h100` (5 nodes, 40 GPU GRES), and `gpu_h200` (3 nodes, 24 GPU GRES).
Two nodes appear in both the H100 and H200 partitions.
`gpu_h200_mig` (112 slices) and `gpu_a800_mig` (56 slices) are restricted.
The partition QoS `gpu` lists a one-node cap. The job QoS `gpugpu`
has `OverPartQOS` and sets a 16-node cap when requested.

The user association permits `normal` and `gpugpu` with no explicit default
QoS, an aggregate eight-GPU cap and at most 16 submitted jobs. Accounting
enforces association, limit and QoS constraints. Parent associations were
not visible. Recheck live capacity before planning a job.
Slurm accounts resources with `CR_CORE_MEMORY`. The public
partitions advertise unlimited wall time and the visible QoS entries have
no separate wall-time cap.
The controller uses backfill and sets `PrivateData=jobs,reservations,usage`.
`squeue --start -u "$USER"` can estimate starts for the login's pending jobs.

Slurm reports eight GPUs per full node. The A800 partition advertises 64
CPUs, two sockets, one thread per core and 1,030,000 MB per node. The H100
and H200 partitions advertise 192 CPUs, two sockets, two threads per core
and 2,050,000 MB per node. The x86-64 login is AMD EPYC 7402, with two
24-core sockets, one thread per core and eight NUMA nodes. The login exposes
an active 100 Gb/s ConnectX-6 Ethernet port with RoCE v2 GIDs. Compute CPU
models and the compute-node fabric remain unverified.

## Toolchain

GCC 14.2.0, CMake 4.2.0, CUDA 13.0 (nvcc 13.0.48), NCCL 2.28.9, and
NVHPC 25.11 HPC-X 2.25.1 with Open MPI `4.1.9a1` and UCX 1.20.0, all
from site modules. The HPC-X wrapper defaults to NVHPC compilers. The
fixed environment sets both wrappers to the selected GCC installation.
Disposable CUDA/MPI/NCCL compile/link checks passed on the x86-64 login
for CUDA targets `sm_80` (A800) and `sm_90` (H100/H200).
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

The initial 32-worker external build received SIGTERM during HDF5
compilation. An eight-worker retry built HDF5, then installation hit
`Disk quota exceeded`. The workspace was copied to the site's `~/run`
storage and compared by checksum. The canonical workspace path now links
to that copy. The old home directory was retained as a backup. The shared
checkout holds the source and venv, and the new externals and solver build
trees also use `~/run`. The selected profile defaults to eight build workers
after repeated interruptions during the refresh at 16.

The login CPU built and linked the initial `build-cauchy-cuda/app/cauchy.exe` with
Ninja, 16 workers on the final attempt, CUDA and NCCL enabled, and both
equation families and dimensions enabled. `cuobjdump` reported native
`sm_80` and `sm_90` images. The executable resolves the selected
Open MPI, NCCL 2.28.9, CUDA 13.0 and GCC 14.2 runtime libraries.
`libcuda.so.1` is supplied by the compute driver and was absent on the
login. The initial executable SHA-256 is
`3227c49d1d6cd87056fad13ad7ba7a5c470023f9e500305bc33eab6d57efc0ab`.

The refreshed executable linked at eight workers, with the same native
`sm_80` and `sm_90` images and library resolution. Its SHA-256 is
`2331c6464b2c9070842cc4b458c2071d45cd0ba88c5d22ff4f9fb7d67d7472bb`.

No scheduler job or GPU program was run for this setup. Compute driver
compatibility, CUDA-aware transfers and NCCL collectives require runtime
evidence.
