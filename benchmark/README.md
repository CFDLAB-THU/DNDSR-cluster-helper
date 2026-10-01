# Euler3D P3 weak-scaling benchmark

This benchmark measures fourth-order (`maxOrder=3`) VFV steady internal-update
throughput on `bsscm8`, `bsscm9`, `bssca8`, and `thtj1`. The source reference is
DNDSR branch `dev/harry` at commit
`f6ece7e91e97c6337ef0761c30017b2ddad6b24b`.

The tracked report will contain compact manifests and derived timing data. Raw
solver logs, scheduler records, and output directories remain in each cluster's
private run directory.

The completed production results are in [`REPORT.md`](REPORT.md), with compact
machine-readable artifacts under [`results/`](results/). The a8 two-node point
was rejected after repeated UCX connection resets; the report records those
attempts and the accepted full-node matrix.

## Experiment contract

- Solver: `euler3D.exe`.
- Reference case: `cases/euler3D/euler3D_config_BenchTGV.json`.
- Numerical work: VFV `maxOrder=3`, quadrature `intOrder=5`, limiter disabled,
  one physical step, and 500 bounded steady internal updates.
- Parallel model: pure MPI, one rank per physical core, `--cpus-per-task=1`,
  `DNDS_DIST_MT_USE_OMP=OFF` at configure time,
  `DNDS_DIST_OMP_NUM_THREADS=1` and `OMP_NUM_THREADS=1` at runtime, core binding
  enabled, and no oversubscription. Every allocation is exclusive and uses all
  physical cores of every requested node. Each run records the two CMake cache
  values and the two runtime variables.
- Timing: the solver's rank-zero per-update `telapsed` value. Discard updates
  1--100 and measure updates 101--500. Report both
  `global_cells / mean_iteration_seconds` and
  `global_cells / median_iteration_seconds` as cell-iterations/s.
- Acceptance: successful scheduler and application exit, all 400 finite timing
  samples for updates 101--500 (the parser ignores the terminal update 501),
  finite residual output, exact source/config/executable/mesh provenance, and a
  wall time no longer than 60 minutes through 16 nodes, and no longer than 120
  minutes for 24- and 32-node members. The initial thtj1 128-node retry showed
  that two hours is insufficient for high-rank initialization, so its 64- and
  128-node members allow four hours. The 64-node member completed, while the
  128-node member still timed out before solver iterations. The larger meshes
  need this allowance for serial CGNS ingestion and repartitioning; reported
  throughput uses only internal-update timings.
- Stop conditions: scheduler timeout, non-finite state or timing, solver abort,
  missing iteration 100, or a source/config mismatch.

Every allocation uses complete physical nodes; no partial-node member is
allowed. The cluster-specific mesh/rank ladders keep the global average near
1024 cells per rank:

| Cluster | Nodes | MPI ranks | Mesh | Cells/rank |
|---|---:|---:|---|---:|
| `bsscm8` | 1 | 192 | `UP3D_58.cgns` | 1016.21 |
| `bsscm8` | 2 | 384 | `UP3D_73.cgns` | 1013.07 |
| `bsscm8` | 4 | 768 | `UP3D_92.cgns` | 1013.92 |
| `bsscm8` | 8 | 1536 | `UP3D_116.cgns` | 1016.21 |
| `bsscm8` | 16 | 3072 | `UP3D_147.cgns` | 1034.02 |
| `bsscm8` | 24 | 4608 | `UP3D_168.cgns` | 1029.00 |
| `bsscm8` | 32 | 6144 | `UP3D_185.cgns` | 1030.54 |
| `bsscm9` | 1 | 256 | `UP3D_64.cgns` | 1024.00 |
| `bsscm9` | 2 | 512 | `UP3D_81.cgns` | 1037.97 |
| `bsscm9` | 4 | 1024 | `UP3D_102.cgns` | 1036.34 |
| `bsscm9` | 8 | 2048 | `UP3D_128.cgns` | 1024.00 |
| `bsscm9` | 16 | 4096 | `UP3D_161.cgns` | 1018.87 |
| `bsscm9` | 32 | 8192 | `UP3D_203.cgns` | 1021.17 |
| `bssca8` | 1 | 128 | `UP3D_51.cgns` | 1036.34 |
| `bssca8` | 4 | 512 | `UP3D_81.cgns` | 1037.97 |
| `bssca8` | 8 | 1024 | `UP3D_102.cgns` | 1036.34 |
| `bssca8` | 16 | 2048 | `UP3D_128.cgns` | 1024.00 |
| `bssca8` | 24 | 3072 | `UP3D_147.cgns` | 1034.02 |
| `bssca8` | 32 | 4096 | `UP3D_161.cgns` | 1018.87 |
| `thtj1` | 1 | 56 | `UP3D_39.cgns` | 1059.27 |
| `thtj1` | 2 | 112 | `UP3D_49.cgns` | 1050.44 |
| `thtj1` | 4 | 224 | `UP3D_61.cgns` | 1013.31 |
| `thtj1` | 8 | 448 | `UP3D_77.cgns` | 1019.05 |
| `thtj1` | 16 | 896 | `UP3D_97.cgns` | 1018.61 |
| `thtj1` | 32 | 1792 | `UP3D_122.cgns` | 1013.31 |
| `thtj1` | 64 | 3584 | `UP3D_154.cgns` | 1019.05 |
| `thtj1` | 128 | 7168 | `UP3D_194.cgns` | 1018.61 |

The planned a8 two-node member used 256 ranks and `UP3D_64.cgns`, but it is
not part of the accepted matrix because three attempts encountered UCX
connection resets. See the report and failed-attempt record.

## Large-rank failure triage

Treat scheduler state, stdout, and stderr as separate evidence. On this Slurm
installation, the compact `sacct` value `7:0` corresponds to a return value of
135 in the JSON accounting record and in `seff`, consistent with a process
ending through signal 7. The observed m8 and a8 signal-7 attempts all had
zero-byte stderr files. Their stdout files stopped in mesh partitioning or
serial-to-distributed mesh transfer; two m8 attempts reached
`Done PartitionReorderToMeshCell2Cell` before exiting. Enabling UCX and OpenMPI
error/backtrace output did not produce a stack trace.

Do not classify every missing large-rank result as that failure. Slurm marked
three a8 attempts `NODE_FAIL` and identified nodes that were subsequently down
with reason `Node unexpectedly rebooted`. The first thtj1 128-node attempt was
suspended during cluster maintenance and stderr reported that ORTE lost a
remote daemon. Clean 128-node retries then reached two- and four-hour limits at
`ConvertAdjSerial2Global`; the latter stderr contains only Slurm's time-limit
notice. These infrastructure and timeout attempts are recorded separately in
[`failed-attempts.csv`](results/failed-attempts.csv).

The behavior is not a universal rank-count ceiling: the unchanged m9 binary
and default hindexed transfer path completed mesh redistribution and the full
500-update run at 8,192 ranks. `DNDS_DISABLE_ASYNC_MPI=1` changes the requested
MPI thread level but does not change `ArrayTransformer` transfer strategy. The
optional `DNDS_ARRAY_STRATEGY_USE_IN_SITU=1` diagnostic changes from MPI
hindexed datatypes to contiguous packing and must not be mixed into the
production throughput curve. On m8, that packed-transfer diagnostic completed
redistribution at 4,608 ranks, crossing the boundary where the default path had
repeatedly exited, but then exceeded four hours in face interpolation. Treat
this as evidence that transfer strategy affects the early failure, not as a
successful benchmark member or a complete root-cause proof.

The largest full-node member is launched first on each cluster. After it enters
the solver and completes successfully, the remaining production members may
be submitted. This first member is part of the reported matrix.

[`run-full-node.sbatch`](run-full-node.sbatch) is the common rendered job body.
[`summarize.py`](summarize.py) extracts updates 101--500 and writes one compact
JSON result per successful run.
