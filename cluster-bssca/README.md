# bssca: amd_256

**Additional validated 4.x runtime, October 23:** installed **Open MPI
4.1.0-para + UCX 1.8.0 + GCC 12.2** now passes a separately rebuilt solver's
16-node / 1,024-rank startup, checkpoint redistribution and three physical
steps. Their nine implicit stages passed the startup acceptance checks, and
step four was advancing. Use [env/ucx410.sh](env/ucx410.sh) and a
separate build with `-DDNDS_ALLOW_OPENMPI_410=ON`. The default-OFF escape hatch
is in DNDSR commit `4b1b18d9`. MPI, MPI C++, Open RTE and Open PAL all resolve
to the same 4.1.0-para installation; runtime logs verify PML UCX and
`ud_verbs/mlx4_0:1`. This is application startup evidence, not long-run
stability or a reversal of the earlier large-rank 4.1.0 findings on other
clusters. Login defaults were not changed.

**October 23 working runtime:** installed **Open MPI 3.1.4**, GCC **12.2**,
and system **UCX 1.8.0**, with `UCX_TLS=ud_verbs,sm,self` and active
`mlx4_0:1`, passed verified collective probes at 1,024 ranks and one full
solver physical step on 16 nodes. All three implicit stages reached the
requested density tolerance, without iteration caps or non-finite logged
values.
This is a startup/runtime validation, not long-term numerical or scaling
evidence. Use [env/ucx314.sh](env/ucx314.sh) as the scoped runtime environment.
It has not been installed as a login-shell default.

The [MPI startup diagnosis](MPI_STARTUP_DIAGNOSTICS.md) records the all-rank
failure pattern, the solver-independent pure-C zero-count Alltoallv replay,
and the verified working combination. The replay passed with 3.1.4/UCX and
stalled with the installed 4.1.2/OpenIB package at 1,024 ranks, with the same
basic-linear Alltoallv algorithm forced on both.

[The 4.1.0 exclusion retrospective](OPENMPI_410_HISTORY.md) separates the
earlier BSSCA8/BSSCM8 large-rank evidence from this partition's separate
`4.1.0-para` installation and explains the exact configure-time guard.

**Small-layout follow-up:** the same zero-count replay passed on 1, 2 and
3 nodes with installed 4.1.2/OpenIB, but stalled on **4 nodes / 256 ranks**:
two ranks remained in Alltoallv while 254 waited in its following Allgather.
Four nodes is the smallest failing layout in this one-trial sweep at
64 ranks/node; a universal threshold has not been established. The UCX
four-node control passed, all test processes were cleaned up, and the final
queue was empty. See the diagnosis for trace durations and launcher controls.

**Automatic device selection:** `amd_256` also contains nodes with
`mlx5_0` rather than `mlx4_0`. CPU type and host-name prefixes do not reliably
identify the adapter, and the inspected scheduler features are empty. The
fixed `mlx4_0:1` setting above is validated only on its actual allocation;
the reusable runtime helper therefore defaults to `UCX_NET_DEVICES=all`.
Automatic selection passed the full verified collective probe at 128 ranks,
64 per node, on a mixed mlx4/mlx5 pair. A later 1,024-rank full application
comparison also passed startup, checkpoint redistribution and one physical
step with automatic device selection. Its all-rank trace recorded 5,587
completed WORLD collective epochs, including finalization. Restrict devices
only after verifying the actual allocation;
`BSSCA_UCX_NET_DEVICES` provides an optional override. A trial that requested
the wrong device is an invalid transport control, not evidence of an MPI
rank-count failure.

The solver executable was built with 4.1.2 and tested under the older 3.1.4
C MPI runtime. `ldd -r` found no unresolved symbols, all MPI libraries
resolved to 3.1.4, and restart redistribution and time stepping completed.
This is evidence for that executable's checked runtime experiment, not an
unconditional backward-ABI guarantee for other executables. Keep a new
MPI build configuration separate from the existing 4.1.2 CMake cache.
The module named `mpi/openmpi/3.1.4-gcc-thc-public4` has misleading compiler
metadata and a malformed CPATH entry; the runtime script selects the verified
installation prefix directly, retaining GCC 12.2.

**October 23 validation limit:** a 1,024-rank production startup and one
unchanged-settings retry both stalled during global-index mapping. Four
sampled ranks in the retry waited in a small recursive-doubling
`MPI_Allgather` through OpenIB, with logs unchanged for over 15 minutes.
Build success and observed InfiniBand selection therefore do **not** establish
a validated production environment. The 4.1.2/OpenIB setup has not completed
a solver step at that scale.

A later same-allocation comparison clarifies the sampled stack: under
4.1.2/OpenIB, 743 ranks had reached the small Allgather while 281 remained
in the preceding Alltoallv. Every rank recorded zero total send/receive
counts for that Alltoallv. Its selected basic-linear implementation still
posts a persistent send and receive to every other rank: 2,046 requests per
rank at this scale. The pending-rank stack was in that implementation's
request wait. This supplies a focused reproduction target, not proof of a
particular source-level transport bug. Do not diagnose a collective from
only a few rank stacks, or assume a zero-payload collective makes no network
requests. The identical executable passed under 3.1.4/UCX on those same nodes.

The preceding limitation concerns the **4.1.2/OpenIB path**. Standalone
4.1.2 and 4.1.1 OpenIB probes also crashed during MPI initialization, in
`ibv_create_comp_channel`. That initialization crash is distinct from the
original application's Allgather stall. Installed 4.1.0/UCX passed the
standalone probe, but was not used for DNDSR because its configure-time
version guard remains in effect. No new MPI package was built.

TCP controls require an explicit routable interface: unrestricted discovery
attempted the shared virtual-bridge address `192.168.124.1`. Constraining TCP
to `ib0` allowed the checked Allgathers to advance, but the full probe later
stopped in Alltoallv. Treat this as a failed TCP control, not a validated
fallback. Every stalled diagnostic was terminated.

Observed October 22, 2026. This profile reuses an established DNDSR
environment. It is not a fresh dependency installation. Scheduler capacity,
paths and module packaging must be rechecked before subsequent campaigns.

## Target and scheduler

- Slurm **23.11.8**, production partition **amd_256**.
- The inspected node advertises **two sockets, 32 cores per socket, one
  thread per core: 64 physical/scheduled CPUs**, with **256,000 MB** scheduler
  memory. The partition name refers to memory, not 256 CPU cores.
- A full-node pure-MPI run uses **64 ranks/node**, one OpenMP thread/rank.
  Sixteen nodes therefore mean **1,024 ranks**.
- The live partition reports **MaxTime=UNLIMITED**; request an explicit bound
  for every job. A seven-day production limit was selected for this campaign.
- Compile on an allocated compute node, with build parallelism no larger
  than allocated CPUs. The example requests one node and 32 build CPUs.

The actual build allocation reports **AMD EPYC 7452**, two sockets and
**two NUMA nodes**, with 64 CPUs and one thread per core. Network device
class `mlx4` reports vendor ID `0x15b3` and Mellanox device 4099. The inspected
port 1 is **ACTIVE InfiniBand, 56 Gb/s (4x FDR), MTU 4096**; port 2 is down.
Full ISA,
cache and NUMA details remain in the private allocation evidence; no
login-node CPU assumptions are substituted for these compute measurements.

## Existing toolchain and historical 4.1.2 build

Keep the existing **CMake 3.24.1**, **GCC 12.2** and
**OpenBLAS/0.3.7-wxl-public4** environment. The pre-existing custom
**OpenMPI 4.1.0** is rejected by DNDSR because of known large-scale transport
hangs. This concrete blocker required an MPI replacement; no compiler search
or compiler replacement was needed.

The historical build selected **mpi/openmpi/4.1.2-gcc12.2**, whose actual runtime is
**OpenMPI 4.1.2**, and whose wrapper invokes GCC/G++ **12.2**. The fixed
[env/modules.sh](env/modules.sh) loads the existing modules plus this MPI,
then explicitly prepends its vendor install prefix to PATH and library
search paths. Merely loading the module can leave an old custom MPI earlier
in a previously modified PATH. Fresh-login verification is required after
startup-file edits. Preserve timestamped backups before such edits.

The observed compiler defaults are **-march=x86-64, -mtune=generic**. Use
the source checkout's paired build tree and canonical populated externals
and venv. Existing HDF5, CGNS and ParMETIS shared libraries resolved their
MPI dependency to 4.1.2 under the selected scoped environment. Do not
independently rebuild another copy of the same dependencies without a blocker.

## Historical OpenIB runtime and its limits

The selected OpenMPI package advertises PML **ob1**, **cm**, **v** and
**monitoring**, with BTL **self**, **vader**, **tcp** and **openib**.
It has **no UCX PML component**. The old launcher's `UCX_TLS` setting does
not establish a UCX backend for this MPI build. Installed components show
availability only; runtime-selected intra/inter-node backends must be
reported from actual MPI initialization evidence. Do not claim high-speed
fabric use merely because openib is installed.

The observed `btl_openib_allow_ib` default is **false**. With no UCX PML,
leaving that default can bypass the InfiniBand fabric. The fixed environment
therefore selects **PML ob1**, BTL **self,vader,openib**, and explicitly sets
`OMPI_MCA_btl_openib_allow_ib=1`. This uses local shared memory and the
installed verbs backend, with no silent TCP fallback in this profile.
Runtime verbosity on two production ranks will verify actual device and
endpoint selection; installed-component inspection alone is insufficient.

The generic environment keeps the established array-strategy and synchronization
settings, pins OpenBLAS to one thread and makes OpenMP agree with allocated
CPUs per task. Do not carry thtj1-specific GLEX settings onto this cluster.

## Reusable files and validation

- [env/modules.sh](env/modules.sh): historical 4.1.2 build environment; its
  OpenIB runtime is not validated.
- [env/ucx314.sh](env/ucx314.sh): checked 3.1.4/UCX runtime experiment.
- [env/ucx410.sh](env/ucx410.sh): rebuilt 4.1.0-para/UCX application startup;
  requires the explicit CMake guard override in a separate build.
- [examples/compile-amd256.sh](examples/compile-amd256.sh): scheduled build of
  an already configured target; it is not a dry-run command.
- [examples/run-amd256.sbatch](examples/run-amd256.sbatch): production pattern
  with explicit MPI core binding. Copy it into a private run record, set
  absolute stdout/stderr paths and variables, and validate with `bash -n`
  before submission.

Dry-run inspection remains allocation-free. Reuse existing numerical pilot
evidence and use the first intended production run to validate startup.
Build result, compiler/MPI paths, source and executable hashes, actual
allocation hardware, runtime backend and scheduler IDs belong in the private
study record. This public profile intentionally contains no account names,
personal checkout paths, private data paths or credentials.

The October 22 scheduled build of `eulerSA3D` completed successfully in
**3 minutes 43 seconds**, using **32 build CPUs**, GCC 12.2, OpenMPI 4.1.2,
CMake 3.24.1 and Ninja/Release. The source-paired build reused existing
external libraries; final library inspection resolved all MPI libraries to
4.1.2. The executable link used `-Wl,--exclude-libs,ALL` to isolate symbols
from static archives. No fresh dependency install or separate solver pilot
was performed. A full CPU test suite was not rerun for this host migration;
production startup is validated separately from prior source regressions.

When changing MPI rank count, validate mesh mode separately from restart
redistribution. DNDSR `readMeshMode=1` expects a prepartitioned mesh for the
same number of ranks; the default filename embeds the current MPI size.
Use `readMeshMode=0` to read and partition the source CGNS mesh, or mode 2
with an explicitly selected serialized mesh for repartitioning. A restart
with original-cell indices can be redistributed, but that does not make a
mode-1 mesh portable across rank counts.

The first production MPI initialization selected **PML ob1**, local **vader**,
and the **openib mlx4 port 1** backend on two traced ranks. This confirms the
intended backend was initialized; it is not by itself a performance result.
The corrected production run also traced actual cross-node sends through
**openib** and same-node sends through **vader**, on a 16-node / 1,024-rank
allocation. Source CGNS loading and connectivity building passed. Solver
iteration timing is a separate acceptance measurement after mesh startup.

For a large source mesh, the serial-to-global adjacency conversion can be
quiet in the log for several minutes. Record its last progress time and
resource activity and keep setup health unverified until restart loading
and solver steps appear. Advancing Slurm CPU time is not proof of useful
progress, since MPI spin also consumes CPU.
