# `thtj1` cluster profile

Last live inspection: **2026-09-30**.

This profile records a working DNDSR build and production-run pattern for the
`thtj1` Slurm cluster. Re-run
[`examples/inspect-environment.sh`](examples/inspect-environment.sh) before an
operation because partition capacity, node state, modules, and wrapper paths
can change.

## Observed platform

| Item | Observed value |
|---|---|
| Login hostname | `th-ex-ln1` through the local SSH alias `thtj1` |
| Scheduler | Slurm 22.05.2 |
| CPU node shape | commonly 56 physical CPU cores, two 28-core sockets |
| Memory | commonly 250,000 MB per node |
| Compiler | GCC/G++ 12.2.0 |
| CMake | 3.27.7 |
| Active MPI wrapper | `/fs2/software/openmpi/4.1.4-mpi-x-gcc12.2/bin/mpicc` |
| Active MPI runtime | Open MPI 4.1.4 |
| HDF5 module | HDF5 1.14.3 built with Open MPI |
| Generic GPU resource | none observed on `debug6` or `cp6` |

The loaded module list reported an Open MPI **4.1.2** module label while the
active `mpicc` and `mpirun` binaries reported **4.1.4**. Always record
`command -v mpicc`, `mpicc --showme:version`, `command -v mpirun`, and
`mpirun --version`; the active wrappers determine the actual build and runtime.

## Partition choice

| Partition | Use | Observed limit and shape |
|---|---|---|
| `debug6` | compilation and short platform checks | 30-minute maximum; 26 nodes; 56 cores and about 250 GB per node; exclusive nodes |
| `cp6` | production CPU runs | about 2,874 nodes; commonly at least 56 cores and 250 GB per node; no scheduler maximum was reported |
| `cp6bm` | do not assume | present during inspection, but not validated for the DNDSR workflow |

Always specify a finite wall time on `cp6`, even though Slurm currently reports
an unlimited partition maximum. Do not compile on the login node. Do not spend
an allocation on a dry run.

## Recommended workflow

### 1. Inspect without an allocation

```bash
ssh thtj1 'bash -s' < cluster-thtj1/examples/inspect-environment.sh
```

This collects the scheduler version, concise partition facts, compiler/MPI
wrappers, and loaded modules. It intentionally does not invoke `srun`,
`salloc`, `sbatch`, or MPI.

### 2. Compile on `debug6`

The build tree must already be configured for the same source tree. The helper
requests one task with 16 CPUs and keeps build parallelism at 16:

```bash
SOURCE_DIR=/absolute/path/to/source \
BUILD_DIR=/absolute/path/to/source/build \
TARGET=euler \
COMM_ENV=/absolute/path/to/ucx-glex.sh \
bash cluster-thtj1/examples/compile-debug6.sh
```

The script checks that the source, build directory, and environment file exist
before requesting an allocation. It does not configure CMake or clean the
build. If a required build cannot fit within 30 minutes, reassess the target or
build state instead of moving compilation silently to a production partition.

### 3. Prepare a production job

Copy [`examples/run-cp6.sbatch`](examples/run-cp6.sbatch) into the study's run
record and edit its resource request if needed. For a pure-MPI one-node case,
the baseline is 56 ranks, one CPU per rank, and one OpenMP thread per rank.

The log directory must exist **before** `sbatch` opens its output file:

```bash
RUN_DIR=/absolute/path/to/run
HELPER_ROOT=/absolute/path/to/DNDSR-cluster-helper
mkdir -p "$RUN_DIR/logs"
cd "$RUN_DIR"
job_id=$(sbatch --parsable \
  --export=ALL,EXECUTABLE=/absolute/path/to/euler.exe,CONFIG=/absolute/path/to/input.json,RUN_DIR="$RUN_DIR",COMM_ENV="$HELPER_ROOT/cluster-thtj1/env/ucx-glex.sh" \
  "$HELPER_ROOT/cluster-thtj1/examples/run-cp6.sbatch")
printf 'job_id=%s\n' "$job_id"
```

For many cases, submit one real matrix member first. Confirm that it is
running the solver, advancing physical steps, and retaining finite positive
state before submitting the remaining members. This first job is part of the
production matrix, not an extra pilot.

### 4. Monitor and accept

Use low-frequency checks keyed by job ID:

```bash
squeue -j "$job_id" -o '%.18i|%.12P|%.24j|%.2t|%.10M|%.10l|%.4D|%R'
sacct -j "$job_id" \
  --format=JobIDRaw,State,ExitCode,Elapsed,Timelimit,AllocCPUS,MaxRSS -n -P
scontrol show job "$job_id"
```

After the job leaves `squeue`, require all application-level acceptance gates:

- terminal Slurm state and exit code are successful;
- the requested physical step or final time was reached;
- reported fields and residual markers are finite;
- density and energy remain positive when the case requires positivity;
- validation-error lists are empty;
- the expected final output exists and is nonempty.

## Communication environment

[`env/ucx-glex.sh`](env/ucx-glex.sh) mirrors the UCX/GLEX settings that worked
for DNDSR's Open MPI runs during the inspection campaign. Source it inside the
allocated job after the compiler/MPI modules are established.

`DNDS_DISABLE_ASYNC_MPI=1` is included in the job example because this stack
did not provide the MPI thread behavior required by DNDSR's asynchronous MPI
path. Keep it unless a deliberate platform test establishes otherwise.

## Operations that can be slow

- SSH login and remote filesystem metadata can pause for tens of seconds.
  Bundle related read-only checks into one SSH session.
- Git operations on the shared filesystem can be slow. Fetch only the needed
  ref and allow a generous client timeout; avoid repeated status and recursive
  filesystem scans.
- Copying VTKHDF snapshots can be much slower than their size suggests. Keep
  ordinary raw output on the cluster and fetch compact records, logs, tables,
  and final snapshots. Use `rsync --partial` for restartable large transfers.
- Scheduler queries can briefly lag job completion. Treat `squeue`
  disappearance as a prompt to query `sacct`, never as proof of success.
- Builds should use the existing configured build tree and a specific target.
  Reconfiguration and broad rebuilds increase metadata traffic and often cost
  more than compilation itself.

## Provenance checklist

For every production result, retain:

- full source commit and clean/dirty status;
- executable SHA-256;
- input/config SHA-256 and command-line overrides;
- mesh/data SHA-256 where applicable;
- rendered `sbatch` script and communication environment;
- nodes, ranks, CPUs per task, threads, partition, and wall time;
- job ID, node list, start/end time, Slurm state, and exit code;
- application log path, raw-output path, and compact validation record;
- checksums for copied final artifacts.
