# MPI startup stall and working runtime on BSSCA

Observed **2026-10-23**, Slurm partition `amd_256`, **16 nodes / 1,024 ranks**,
64 ranks per node, one CPU and one OpenMP thread per rank. These observations
apply to the installed packages tested here; they are not a verdict on every
build of these MPI releases.

**Later application validation:** a fresh build using installed
4.1.0-para/UCX and the explicit `DNDS_ALLOW_OPENMPI_410=ON` guard override
also passed the 16-node startup and checkpoint redistribution. At the
acceptance snapshot, three physical steps had completed with finite logged
values and their nine implicit stages meeting the density criterion; step
four was advancing. All MPI/core libraries belong to that same 4.1.0 package,
and runtime logs confirm UCX UD verbs. The following 3.1.4/UCX versus
4.1.2/OpenIB comparison
records remain valid; the new result is documented in
[the 4.1.0 history and follow-up](OPENMPI_410_HISTORY.md) and
[the profile](README.md). Long-run stability remains unverified.

## Working combination

Use the existing **Open MPI 3.1.4 + system UCX 1.8.0 + GCC 12.2** environment
in [env/ucx314.sh](env/ucx314.sh). It selects:

```bash
export BSSCA_MPI_ROOT=/public4/soft/openmpi/3.1.4-pmi2-gcc
export OMPI_MCA_mca_base_component_path="$BSSCA_MPI_ROOT/lib/openmpi"
export OMPI_MCA_pml=ucx
export OMPI_MCA_btl=self,vader
export UCX_TLS=ud_verbs,sm,self
export UCX_NET_DEVICES=all
```

The helper also sets the matching executable/library paths and loads the
existing GCC, CMake and OpenBLAS modules. Source it after initializing the
site module command. Do not copy just the PML variables into a different MPI
installation: the tested 4.1.2 installation has **no UCX PML**. The helper is
scoped to its shell; this investigation did not change the login default.

Automatic device selection matters because the partition contains both
`mlx4_0` and `mlx5_0` adapters. Do not globally pin `mlx4_0:1`. A mixed-adapter
128-rank test passed; the full 1,024-rank application also passed with automatic
selection on its observed allocation. Runtime verbosity in the standalone
comparison confirmed UCX tag traffic over `ud_verbs/mlx4_0:1`, rather than
merely relying on installed-component metadata or permitting TCP fallback.

| Test | Existing 3.1.4 / UCX | Existing 4.1.2 / OpenIB |
|---|---|---|
| Checked general collective probe, 1,024 ranks | Passed | Earlier C++ probes failed during initialization |
| Same-application comparison on the same 16 nodes | Startup, checkpoint redistribution and one physical step passed | Stalled across consecutive Alltoallv and Allgather calls |
| Pure-C zero-count Alltoallv replay, same 16 nodes and forced basic-linear algorithm | Passed; rank-0 Alltoallv time 2.376 s, followed by checked Allgather and finalization | Initialized and passed the prefix; all 1,024 ranks remained in Alltoallv at timeout |

The application trace contains **5,587 completed WORLD collective epochs on
every rank**, with no detected WORLD operation/count-signature divergence or
nonzero MPI return code. Its three implicit stages passed the configured
criterion and its logged values were finite. This validates startup and a
bounded step, not long-run stability or scaling.

That application executable had been built against 4.1.2 and used the C MPI
API. Its relocations and selected 3.1.4 runtime libraries were checked. This
particular backward-runtime experiment is not a general ABI guarantee. Keep
different MPI build caches separate and rebuild with the intended MPI when
establishing a new build configuration. No new MPI or compiler was installed
to obtain the successful runtime.

## Failing pattern

Sampled application ranks appeared to hang in a one-int64 `MPI_Allgather`
inside global-index mapping. All-rank PMPI tracing revealed a more specific
pattern: **743 ranks had entered WORLD epoch 16, Allgather, while 281 still
had not returned from epoch 15, Alltoallv**. The latter call recorded zero
total send and receive counts on every rank. The split initially changed
slowly, then stopped advancing. A pending-rank stack was in
`ompi_coll_base_alltoallv_intra_basic_linear` → `ompi_request_default_wait_all`.
An Allgather stack on a few ranks therefore concealed an earlier unfinished
collective on other ranks.

The installed 4.1.2 source at
`ompi/mca/coll/base/coll_base_alltoallv.c` posts a persistent receive and send
for every other rank in `ompi_coll_base_alltoallv_intra_basic_linear`, even
when counts are zero. It starts all of them and waits. At 1,024 ranks that
means **2,046 persistent requests per rank**. Zero payload does not imply
zero communication in this algorithm.

The standalone confirmation used a **plain C executable**, independently
compiled with each installation's `mpicc`; it had no solver, mesh, deprecated
MPI C++ binding or `libstdc++` dependency. It requested
`MPI_THREAD_MULTIPLE`, which both runtimes provided. It replayed the observed
startup WORLD operation/count/type order with synthetic vector data:

1. Barrier, scalar integer logical-AND Allreduce, two scalar int64 broadcasts,
   scalar int64 SUM Allreduce, Barrier.
2. Scalar integer Allgather, scalar int64 Allgather.
3. Two pairs of SUM Allreduce and SUM Scan on 1,024 int64 elements.
4. Scalar int64 Allgather; one-int-per-peer Alltoall of explicit zero counts.
5. Alltoallv with all counts/displacements zero, valid int64 datatypes and
   separate valid non-null dummy send/receive buffers.
6. A locally checked scalar int64 Allgather and finalization.

No extra timing reduction or barrier was inserted between these operations.
Both installed MCA inventories verified algorithm 1 as `basic_linear`; both
rows explicitly set:

```bash
export OMPI_MCA_coll_tuned_use_dynamic_rules=1
export OMPI_MCA_coll_tuned_alltoallv_algorithm=1
```

UCX completed every call on all 1,024 ranks. OpenIB completed epochs 1–14
on all ranks, then **no rank returned from epoch 15**. Its captured stack
entered basic-linear Alltoallv and `mca_pml_ob1_start`. The 90-second command
bound and termination grace ended the failed row; its launcher status was
137. This is distinct from the earlier probes' initialization crashes.

The replay establishes a solver-independent failure of the tested
package/runtime path with valid zero-count arguments. Version and transport
change together in the successful alternative; the experiment does not
separate those contributions or identify the ultimate OpenIB/verbs defect.
Changing only an Allgather algorithm is not a demonstrated repair.

## Smallest failing tested layout: one through four nodes

A subsequent bounded campaign used the same plain-C prefix replay, valid
dummy buffers, thread level MULTIPLE and forced basic-linear algorithm.
Every row used **64 ranks per node**, with explicit `host:64` slot counts and
core binding. Rows used nested subsets of the same four-node allocation.
Times below are the maximum **within-rank enter-to-exit duration** from the
trace, without added timing collectives or cross-node clock comparisons.

| Installed runtime | Nodes | Ranks | Zero-count Alltoallv | Complete replay |
|---|---:|---:|---|---|
| 3.1.4 / UCX control | 4 | 256 | All returned; max **0.533134 s** | Passed through finalization |
| 4.1.2 / OpenIB | 1 | 64 | All returned; max **0.000872 s** | Passed through finalization |
| 4.1.2 / OpenIB | 2 | 128 | All returned; max **5.143597 s** | Passed through finalization |
| 4.1.2 / OpenIB | 3 | 192 | All returned; max **10.619352 s** | Passed through finalization |
| 4.1.2 / OpenIB | 4 | 256 | **2 ranks did not return**; 254 returned, max among returners **15.998272 s** | Timed out at the 90 s command bound |

At four nodes, **254 ranks waited in the following WORLD epoch 16 Allgather,
while two remained in epoch 15 Alltoallv**. All 256 trace files were captured.
Each passing row has all 17 WORLD epochs through finalization, no pending
intercepted call, no detected operation/count-signature divergence and no
nonzero MPI return code. The incomplete row's sampled Allgather stacks must
not be interpreted as every rank entering that call. The two still-pending
Alltoallv ranks' live stacks were not captured before timeout cleanup.

**Four nodes / 256 ranks is the smallest failing layout in this sweep.**
This is one trial on the observed hosts; it is not a universal deterministic
threshold or a binary search in rank count. Different placement, adapter or
runtime conditions may change it. Even the passing two- and three-node rows
show seconds of cost for zero payload, whereas the UCX four-node control
finished the target in about half a second.

The failed row was terminated by its command bound. Exact-job executable/
daemon cleanup was verified before the allocation finished. The final
timestamped queue check was empty. The wrapper job's successful exit describes
completion of the diagnostic campaign, not a pass of every MPI row.

The first submission of this sweep rejected all OpenIB rows before startup
because bare `--host` names were interpreted as one slot each by that MPI
installation. Those rows are **launcher failures**, not collective tests.
The corrected retry explicitly declared 64 slots per selected node; it did
not use oversubscription or change the MPI workload. Preserve this distinction
when reusing host-subset scripts across MPI versions.

## Operational lessons

Inspect collective entry/exit records on all ranks before concluding that
every rank waits in the same call. Compare communicator identity, sequence,
operation and arguments. WORLD sequence counters must exclude root-only
COMM_SELF operations. Do not compare unsynchronized monotonic clocks across
nodes, or mistake other ranks waiting during root's mesh processing for a
stall.

Use node-local traces and archive them before cancellation. Keep diagnostics
bounded, terminate only the job's exact processes, and do not retain stalled
allocations. A cancelled accounting entry is not proof that node cleanup has
finished: one cancelled application allocation remained in Slurm
`COMPLETING` on five nodes, while a repeat exact-job full-KILL request returned
`Invalid job id`. Native scheduler tools and cluster identity were checked;
the discrepancy was not an alias or cluster override. Node SSH was denied
after allocation removal, so final orphan absence could not be independently
verified. Record this cleanup limitation and exclude affected nodes from
follow-up diagnostics rather than reporting an empty queue.

No diagnostic job was left RUNNING or PENDING. The working runtime was not
automatically promoted to a long production continuation.

The final allocation-free helper check at **13:38 on 2026-10-23** confirmed
that it preserves caller shell flags/nounset, clears inherited diagnostic
Allgather/Alltoallv algorithm choices, selects automatic devices and resolves
the intended MPI/core libraries and system UCX. The five-node scheduler cleanup
limitation above was still present at that observation.

**Cleanup follow-up:** fresh queue observations at **13:45 and 13:47 on
2026-10-23** were empty. The cancelled allocation had finally left the live
queue without further retries or production submissions. Preserve the earlier
cleanup delay as an observed operational limitation, rather than treating it
as an ongoing running job.
