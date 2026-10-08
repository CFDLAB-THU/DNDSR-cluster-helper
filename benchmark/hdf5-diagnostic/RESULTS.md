# Results

These runs test whether a mesh serialized with 64 local oversubscribed MPI
ranks can replace the direct CGNS path at the largest unsuccessful benchmark
sizes. A result is accepted as a throughput result when all 400 post-warmup
timings are present and the MPI/application step exits zero. A top-level Slurm
timeout during allocation cleanup is also accepted when the batch and MPI
steps report zero and the launcher records `BENCH_EXIT status=0`.

## BSSC outcomes

Neither 32-node BSSC run reached the Euler update loop, so neither yields a
throughput sample.

| Cluster | Job | Elapsed | Last durable milestone | Scheduler result |
|---|---:|---:|---|---|
| `bsscm8` | 4857297 | 00:27:38 | 64-way HDF5 even-split read completed at 6,144 ranks; distributed cell-to-cell construction started | `FAILED`, `7:0`; `seff` reports exit code 135 |
| `bssca8` | 4857296 | 00:34:17 | ParMetis completed at 4,096 ranks and redistribution started | `FAILED`, `7:0`; `seff` reports exit code 135 |

Both stderr files are empty. The batch and MPI accounting records do not name
an offending rank. Scheduler step accounting reports about 17 GB maximum RSS,
while `seff` estimates 510.45 GB total for m8 and 486.68 GB total for a8 across
32 nodes, far below either allocation. No core file was retained. The current
login environments report `ulimit -c = 0`, but the original launcher did not
record the in-allocation limit, so the record cannot claim that value for the
failed steps or provide a faulting stack.

The combination of Slurm `ExitCode=7:0` and `seff`'s 135 is consistent with
the conventional `128 + SIGBUS(7)` shell status, but the retained output does
not prove which rank or library raised it. The record therefore treats SIGBUS
as the strongest interpretation rather than as a recovered backtrace.

The retained raw artifacts can be checked without publishing cluster-private
paths or node lists:

| Cluster | stdout SHA-256 | stderr SHA-256 | rendered config SHA-256 | phase log SHA-256 |
|---|---|---|---|---|
| `bsscm8` | `194049aa564029dc2420fbe7af9254736fee93a31bd1c179715301a29d5079f1` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | `86f50607f279c36dbfaf9ac4fc4858553e83b038188870bd5fd37c30e453caaa` | `2cdf97283543b1ef5b1902618b37eb00cf29532c3006b8d64b0ddd48ae18993c` |
| `bssca8` | `8880908c0dc56ed774941603f7069e0d004cc8b131b445cabd4612781efd9a89` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | `e6854885f94f6f21efebeb0dfb23293f61d5e64794ff0acdc79ebaffb81d3feb` | `5fc57a222a4e31b12cfed8c85134f20216d16d514c4cfa4d9562e2cdcd558fc7` |

The a8 partition report is direct evidence that the alternate read and loose
ParMetis path itself works at 4,096 ranks: 4,173,281 cells were repartitioned
to 949--1,054 cells per rank, with min/max ratio 0.9004. Its subsequent failure
during redistribution, together with m8's earlier failure and the common
scheduler signature, shows that the original large-rank failure is not unique
to m8 and is not removed merely by replacing CGNS input with collective HDF5.

## Full-node scale controls

The same HDF5 inputs were rerun on complete 16- and 24-node allocations. These
are diagnostic controls, not additions to the parent weak-scaling curve,
because reusing the largest mesh changes cells per rank.

| Cluster | Job | Nodes | Ranks | Outcome | ParMetis cells/rank |
|---|---:|---:|---:|---|---|
| `bssca8` | 5061792 | 16 | 2,048 | completed 500 updates; 400 steady samples | 1,929--2,101, ratio 0.9181 |
| `bssca8` | 5061853 | 24 | 3,072 | completed 500 updates; 400 steady samples | 1,275--1,402, ratio 0.9094 |
| `bsscm8` | 5061791 | 16 | 3,072 | completed 500 updates; 400 steady samples | 1,957--2,126, ratio 0.9205 |
| `bsscm8` | 5061854 | 24 | 4,608 | redistribution completed; one-hour limit expired before solver updates | 1,290--1,417, ratio 0.9104 |

The successful controls prove that the HDF5 files, their 64-rank writer
layout, ParMetis settings, and redistribution path are valid on both BSSC
clusters. They also show that the failures are scale dependent. The a8 HDF5
path completes at 3,072 ranks but fails at 4,096. The m8 path completes the
full run at 3,072 ranks and completes redistribution at 4,608; its 6,144-rank
case stops earlier while constructing distributed cell adjacency.

The m8 one-hour control is classified as a timeout, not a crash. It printed
`redistribute done`, the final global entity totals, and every rank's final
cell/node/boundary counts. Its stderr contains the scheduler time-limit notice
followed by ORTE reporting loss of a daemon while the allocation was being
terminated. This is distinct from the empty-stderr return-135 failures.

The successful raw control artifacts have empty stderr. Their retained stdout
hashes are:

| Cluster/job | stdout SHA-256 |
|---|---|
| `bssca8` 5061792 | `27def3167b33d601d41d7a349e400ee95b2efa9880717a029cee76d1101b4549` |
| `bssca8` 5061853 | `b9cfe7d84e22e671227ba30d7ba366bbf068d2cc64924350c4f1c7145ea9dde3` |
| `bsscm8` 5061791 | `089942d1a20aecfd4747dcb539e71b2ed72ec48538eae3c35c054a3a2ac5cb62` |

Job 5061854 has stdout SHA-256
`7139ce7aa5b7f97be07022aed08a670707b99e678658fe6d92d9799da87b1164`
and stderr SHA-256
`4b7749a13e978c8d00b4c20c1cdbd36c4be1872c4156933d31d8333e1fc8a4d1`.

## MPI-stack evidence

The failing a8 and m8 reference environments use Open MPI 4.1.0 with UCX
1.14.0. The m9 reference environment uses Open MPI 4.1.8 with UCX 1.18.0 and
has already completed the parent benchmark at 8,192 ranks through the default
hindexed transfer strategy. Same-mesh 4,096-rank m9 HDF5 comparison job
5776806 initially inherited a 2,700 MiB-per-CPU memory request, or about
675 GiB per node and 10.8 TiB total, which excluded most otherwise idle
768-GiB nodes. The request was corrected in place to 128 GiB per exclusive
node and a 20-minute time limit.

Job 5776806 completed mesh redistribution, all 500 updates, and all 400 steady
samples. The batch and 4,096-rank MPI steps completed `0:0`, and stdout records
`BENCH_EXIT status=0`. Slurm marked only the top-level allocation `TIMEOUT` at
00:20:04, after the shortened limit was reached during cleanup. Under the
application-completion acceptance rule, this is an accepted throughput result.
The accepted iteration-time mean is 0.196684210 s and the median is
0.149766460 s, corresponding to 21,218,180.197 and 27,865,257.775 cell
iterations/s. ParMetis produced 949--1,054 cells per rank (ratio 0.9004).
Its stdout SHA-256 is
`0cdf368e4c10760bb1ceade7bb069dcd75ba80bbe117f40345b16c2c11ee24ee`;
stderr SHA-256 is
`fb28a52c25e9fd8f591c10346ad164a1f6d9813904373b0d2ff71572a2bf2a96`.
The 58-byte stderr contains only module-manager unload/load notices.

Before that exact-scale comparison ran, full-node smoke job 5785185 exercised
the same N=161 HDF5 file and m9 software stack on 256 MPI ranks. It completed
in 00:13:31 with scheduler exit `0:0`, repartitioned the 64-writer file to
14,437--16,500 cells per rank (ratio 0.8750), and produced all 400 steady
samples. The accepted iteration-time mean was 1.536788072 s and the median was
1.498474903 s, corresponding to 2,715,586.539 and 2,785,018.949 cell
iterations/s respectively. These values are diagnostic rather than a weak
scaling point because the run carries about 16 times the target cells per
rank. Its stdout SHA-256 is
`6aa738e0f3f167b13ad293c20d307fa121cf6fc6208ff8bf564b1bfc07fbd779`;
stderr SHA-256 is
`fb28a52c25e9fd8f591c10346ad164a1f6d9813904373b0d2ff71572a2bf2a96`.
The 58-byte stderr contains only the module manager's unload/load notices.

The direct BSSC A/B runs below isolate the Open MPI 4.1.0 module stack as the
variable responsible for the silent large-rank failures in these tests. The
executable, mesh, rank count, partition settings, and UCX 1.14.0 remain fixed
while the runtime MPI module changes. This result also agrees with the
packed-transfer m8 diagnostic crossing the earlier failure boundary and the
no-KNEM a8 repeat failing. Open MPI's
[official 4.1.x changelog](https://docs.open-mpi.org/en/main/release-notes/changelog/v4.1.x.html)
records datatype failure fixes in 4.1.1 and UCX datatype reference-count and
leak fixes in 4.1.6, both newer than the BSSC 4.1.0 installation. The m9 HDF5
comparison remains useful as an independent check, but it is no longer needed
to distinguish the BSSC Open MPI releases.

m8 also provides an Open MPI 5.0.10 module built with GCC 14.2. The unchanged
reference executable resolves against that module's `libmpi.so.40`; a one-node
full-MPI smoke, job 5062938, completed all 500 updates in 00:01:21. This smoke
kept UCX 1.14.0, so it verifies the executable/module ABI while isolating the
MPI module stack from the UCX version. Job 5062953 is the corresponding
32-node, 6,144-rank HDF5 A/B. It completed in 00:07:26 with scheduler exit
`0:0`, redistributed to 938--1,065 cells per rank (ratio 0.8808), and produced
all 400 steady samples. This is a direct pass for the exact binary, HDF5 mesh,
rank count, partition settings, and UCX version that failed under Open MPI
4.1.0.

The Open MPI 5 module emitted one HCOLL fallback message per rank and 144 UCX
request-pool warnings during finalization, but the job completed cleanly. Its
stdout SHA-256 is
`b4f906159d8345a50b8bdd05bc4c3f7e0391546c5b373ad82ce09dc27d2d38e1`;
stderr SHA-256 is
`505fae6eb08c759d447e88d815f250a843f921d805e95462994b74546784cb99`.

a8 provides Open MPI 4.1.6 built with AOCC 5. The existing GCC-built
executable is MPI-ABI compatible after retaining the GCC 14 C++ runtime path;
one-node smoke job 5062972 completed all 500 updates in 00:00:54. Job 5062991
is the corresponding 32-node, 4,096-rank HDF5 A/B. It completed in 00:03:25
with scheduler exit `0:0`, redistributed to 949--1,054 cells per rank (ratio
0.9004), and produced all 400 steady samples. This is a direct pass for the
exact binary, HDF5 mesh, rank count, partition settings, and UCX version that
failed under Open MPI 4.1.0. Its stdout SHA-256 is
`5c936245a45dabf826f858044d2bf8b5ee2893ef324a3809f5f1b519ec8eb8b`;
stderr SHA-256 is
`f73f61a3a927dad812345a10c48d6c5582b36a2ee31daa86e51f8f6e878dd1b1`.
The 70-byte stderr contains only the module manager's two load notices.

The preceding job 5062970 only diagnosed the missing GCC C++ runtime and never
entered MPI, so it is excluded from the result table. Together with the m8
Open MPI 5 run, job 5062991 shows that UCX 1.14.0 and the application binary
are usable at both exact failure scales once Open MPI 4.1.0 is replaced. The
evidence does not identify the precise Open MPI internal fault because the
4.1.0 failures retained no backtrace. The default DNDSR transfer uses MPI
hindexed datatypes, so the transfer-strategy A/B and upstream datatype fixes
make datatype handling the strongest mechanism-level explanation.

A four-hour retry of the Open MPI 4.1.0 4,608-rank control, job 5062909, was
cancelled after 00:06:51 while in ParMetis so the account CPU quota could run
the more discriminating 6,144-rank Open MPI 5 A/B. It adds no result and is
retained in `results.csv` only as an excluded submission record.

The reference executable also completed a local 64-rank oversubscribed N=161
HDF5 read and redistribution with Open MPI 5.0.9. That run included ranks with
zero final boundary entities, so an empty boundary partition alone does not
explain the cluster failures.

## thtj1 status

Job 11822048 was submitted on 128 full nodes (7,168 ranks) with the 64-way N=194
HDF5 mesh. It reached the four-hour limit while building distributed
cell-to-cell connectivity after the even-split HDF5 read. It produced no Euler
iteration samples and is therefore rejected as a throughput result. Slurm
reports `TIMEOUT` at 04:00:26; the 102-byte stderr contains only the scheduler
time-limit notice. Its stdout SHA-256 is
`b402e0c305a5445090def53c771eaa2f8387dabe1c7603c6f884619ea194ea52`;
stderr SHA-256 is
`ff59682bd9fb7addb0be5b4e67901c0ab571085a1b445d4828f9811f3514f89e`.

## Controlled BSSC transport repeat

Job 5060537 repeats the a8 32-node case with the same binary, mesh, HDF5 read,
ParMetis inputs, and workload. It forces PML UCX while setting
`UCX_TLS=^xpmem,knem`, leaving the InfiniBand and other available intra-node
transports eligible. UCX backtrace handling and unaggregated Open MPI help are
enabled. This isolates KNEM from the baseline and improves signal diagnostics;
it does not redefine the cluster's normal transport policy.

The repeat also failed during redistribution, after 00:41:09, with Slurm
`ExitCode=1:0`. Its stderr is empty and the launcher's post-`mpirun`
`BENCH_EXIT` marker was not reached. All 32 allocated nodes subsequently
reported `idle` with no scheduler reason, and Slurm recorded no failed node or
system comment. Excluding KNEM therefore changed the timing and exit signature
but did not make the 4,096-rank redistribution complete.

Live monitoring observed facial filtering at about 17:59, the partition report
at about 22:01, and redistribution at about 23:56. The baseline observations
were about 19:17, 23:55, and 26:01 respectively, followed by failure at
00:34:17. These phase times are monitoring observations rather than timestamps
embedded in the solver log.

The repeat's raw artifact hashes are:

| Artifact | SHA-256 |
|---|---|
| stdout | `0f846cc4ca0b4b5598aaf86a0d35d0a055744bf9dd2df2ffe5ee4e72cff2762b` |
| empty stderr | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| rendered config | `6ac32ebc31ea0be11b899794dea2f90ac993d055bd921a8ddb5a7f689f5902c8` |
| phase log | `5fc57a222a4e31b12cfed8c85134f20216d16d514c4cfa4d9562e2cdcd558fc7` |

An earlier submission, job 5060499, was cancelled after 27 seconds because a
deprecated diagnostic MCA variable printed one warning per rank. It had not
entered mesh processing and is excluded from the scientific comparison.
