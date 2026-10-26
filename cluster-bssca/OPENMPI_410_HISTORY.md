# Why DNDSR rejects Open MPI 4.1.0

Retrospective checked on **2026-10-23** against Git history, retained
benchmark records and the upstream release notes. No version guard was changed
and no historical job was rerun for this review.

## Origin and exact scope of the guard

DNDSR commit `0f986c9b3f4280677317bba8b34d5b449adabc5c`, dated
**2026-10-13**, added `cmake/DndsMPIVersion.cmake` and the build-guide warning.
The guard compiles a small program against the headers selected by FindMPI.
It rejects exactly `OMPI_MAJOR_VERSION == 4`, `OMPI_MINOR_VERSION == 1`,
`OMPI_RELEASE_VERSION == 0`. It does not run MPI or test the transport. It
rechecks on reconfiguration instead of trusting a cached result or an
unrelated `mpirun` on PATH.

The diagnostic says the release can hang in transport at large scales.
This is a conservative release-wide policy derived from failed installed
stacks; it is not a package-specific runtime diagnosis or proof that every
4.1.0 build fails at every scale.

## Earlier evidence behind the exclusion

The evidence predates the Orion BSSCA investigation. The
[distributed-HDF5 diagnostic](../benchmark/hdf5-diagnostic/RESULTS.md)
tested the **BSSCA8** and **BSSCM8** clusters, which have different hardware,
packages and UCX versions from the older BSSCA `amd_256` partition. Their
reference installations were Open MPI **4.1.0 + UCX 1.14.0**.

| Cluster and fixed workload | 4.1.0 result | Replacement with the same application binary, mesh, rank count and UCX version |
|---|---|---|
| BSSCA8, 32 nodes / 4,096 ranks, N=161 HDF5 mesh | Job 4857296 failed during redistribution after ParMetis; no solver update samples | 4.1.6/AOCC package, retaining the GCC C++ runtime: job 5062991 completed all 500 updates, exit 0, in 3 min 25 s |
| BSSCM8, 32 nodes / 6,144 ranks, N=185 HDF5 mesh | Job 4857297 failed during distributed adjacency construction; no solver update samples | 5.0.10/GCC package: job 5062953 completed all 500 updates, exit 0, in 7 min 26 s |

The old failing jobs had empty stderr and shell/accounting statuses consistent
with SIGBUS, but no retained core or faulting backtrace. Do not rewrite those
particular observations as a proven collective deadlock. The m8 one-hour
4,608-rank run was a timeout after redistribution, not the same crash.

The 4.1.0 stack also **passed smaller full runs**: BSSCA8 at 2,048 and
3,072 ranks, and BSSCM8 at 3,072 ranks. Thus the records support a scale-
and workload-dependent problem, not universal failure. The direct runtime
replacements isolated the MPI module stack as the changed component; they
did not isolate one upstream source patch or exclude every packaging-level
difference between builds.

Default hindexed transfer, a packed-transfer diagnostic crossing an earlier
failure boundary, and upstream datatype fixes support datatype handling as a
plausible mechanism. The precise internal cause remains unproved.

## Upstream context and a corrected release attribution

The [official 4.1.x changelog](https://docs.open-mpi.org/en/main/release-notes/changelog/v4.1.x.html)
lists datatype/partial-datatype fixes in **4.1.1**, UCX datatype reference-count
and leak fixes in **4.1.2**, and a UCX PML datatype-handling thread race fix
in **4.1.4**. These are relevant context, not proof of which fix addressed the
retained benchmark failure. The old benchmark report incorrectly attributed
the reference-count/leak fixes to 4.1.6; that attribution was corrected during
this retrospective.

The same changelog says 4.1.1 disabled the UCX PML when detecting **UCX 1.8.0**
because of corruption involving the **TCP plus shared-memory** transport
combination. This is relevant to interpreting why BSSCA's installed newer
MPI packages may lack UCX, but it does not by itself establish their exact
configure decision. The tested working 3.1.4 configuration explicitly uses
`UCX_TLS=ud_verbs,sm,self`, excluding TCP; its validation scope is recorded
in [the current MPI diagnosis](MPI_STARTUP_DIAGNOSTICS.md).

## Implication for BSSCA's existing 4.1.0-para

The separate `/public4/soft/openmpi/4.1.0-para` UCX package passed the earlier
standalone collective probe at 2 and 1,024 ranks. At the time of the initial
retrospective it had not completed an Orion startup or the later zero-count
Alltoallv replay in this investigation.
Those successes are evidence for that package and probe; they neither
invalidate the historical large-rank failures on other clusters nor justify
claiming this package fails for the same reason.

At the time of the retrospective the guard was unchanged. It is a configure-
time check, not a dynamic check when an already built executable is launched
under a different runtime. Such runtime experiments need explicit library/ABI
verification and their own bounded workload evidence.

## Subsequent explicit escape hatch

The user subsequently authorized a controlled 4.1.0-para/UCX build and Orion
startup on BSSCA. DNDSR now has an opt-in CMake BOOL,
`DNDS_ALLOW_OPENMPI_410`, default **OFF**. Set
`-DDNDS_ALLOW_OPENMPI_410=ON` in a separate build directory to permit this
release. Configuration prints a warning; unrelated MPI header or link
failures are still rejected. Turning the option back OFF restores the
default exclusion and rechecks the selected headers in the same build cache.
This is an experiment override, not a claim that historical defects are fixed.

The local tooling suite passed all 18 tests, including explicit ON/OFF/ON
reconfiguration and rejection of a broken MPI header while the override is
ON. The hatch was committed and pushed as `4b1b18d9` on DNDSR `dev/harry`.

A separate application build with the 4.1.0-para wrappers and the override
completed successfully. All MPI libraries, including MPI C++, Open RTE and
Open PAL, resolve to that package. The 16-node / 1,024-rank continuation then
passed original-CGNS mesh preparation, checkpoint redistribution/loading,
finite inner iterations and a completed physical step; step 2 was advancing
at the startup-acceptance observation on 2026-10-23. Runtime logging confirms
PML UCX and inter-node `ud_verbs/mlx4_0:1`, with shared memory locally.
Use [env/ucx410.sh](env/ucx410.sh) for the scoped environment. This is a fresh
build against the intended MPI, not a claim of a C-only backward-ABI test.

The validated startup establishes that this installed 4.1.0 package can run
this case at this scale. It does not establish long-run stability, resolve
the historical higher-rank datatype failures, or remove the default guard.
