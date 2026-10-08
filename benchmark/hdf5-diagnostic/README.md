# Distributed-HDF5 large-rank diagnostic

This diagnostic retries the largest unsuccessful members through DNDSR's
collective HDF5 read path. Each source CGNS mesh is prepared on a local machine
with 64 MPI ranks and `--oversubscribe --bind-to none`, then serialized as one
collective `.dnds.h5` file. Cluster runs use `readMeshMode=2`, which performs an
even-split HDF5 read, builds distributed adjacency, calls ParMetis, and
redistributes cells, nodes, and boundaries before normal solver setup.

The numerical workload remains the Euler3D P3 benchmark in the parent
directory. Runs use complete nodes, one MPI rank per physical core, no OpenMP,
500 internal updates, and the same reference source commit. The alternate mesh
path uses `metisType=KWAY`, `metisUfactor=30`, `metisNcuts=1`, seed zero, and no
edge weights. This is deliberately looser than the production CGNS benchmark's
`metisUfactor=3`.

The first matrix is the largest previously unsuccessful member on each affected
cluster:

| Cluster | Nodes | Ranks | Mesh |
|---|---:|---:|---|
| `bsscm8` | 32 | 6144 | `UP3D_185.cgns_part_64.dnds.h5` |
| `bssca8` | 32 | 4096 | `UP3D_161.cgns_part_64.dnds.h5` |
| `thtj1` | 128 | 7168 | `UP3D_194.cgns_part_64.dnds.h5` |

Full-node controls at 16 and 24 nodes locate the scale boundary without
changing the mesh, source, partition options, or pure-MPI execution model.
The controls intentionally have more than 1,024 cells per rank because they
reuse the same prepared HDF5 file; their purpose is failure isolation rather
than weak-scaling throughput.

| Cluster | Nodes | Ranks | Mesh | Purpose |
|---|---:|---:|---|---|
| `bssca8` | 16 | 2048 | N=161 | lower-rank control |
| `bssca8` | 24 | 3072 | N=161 | intermediate-rank control |
| `bsscm8` | 16 | 3072 | N=185 | lower-rank control |
| `bsscm8` | 24 | 4608 | N=185 | intermediate-rank control |
| `bsscm9` | 16 | 4096 | N=161 | same-rank MPI-stack comparison to a8 |
| `bsscm9` | 1 | 256 | N=161 | full-node HDF5-path smoke while 16-node comparison waits |

Direct MPI-version A/B runs repeat the exact 32-node failures with the same
reference executable and UCX 1.14.0. On m8, Open MPI 5.0.10 replaces 4.1.0;
on a8, Open MPI 4.1.6 replaces 4.1.0. Both newer-MPI runs complete all 500
updates. These are diagnostic module selections and do not change the recorded
cluster defaults.

[`run-hdf5-full-node.sbatch`](run-hdf5-full-node.sbatch) is the common rendered
job body. Results are accepted only after a clean scheduler exit and all 400
timings from updates 101--500 are present.

## Mesh preparation

The source-compatible local executable reports commit
`f6ece7e91e97c6337ef0761c30017b2ddad6b24b` and has SHA-256
`cba833bb3aec4c9c96ce870b9cf88116f9b9f14bcda90f16534d12f10c774423`.
It was run with Open MPI 5.0.9 on a 32-core/64-thread host. The command shape
for each `N` was:

```bash
OMP_NUM_THREADS=1 DNDS_DIST_OMP_NUM_THREADS=1 \
  OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 BLIS_NUM_THREADS=1 \
  DNDS_DISABLE_ASYNC_MPI=1 \
  mpirun --oversubscribe --bind-to none -np 64 \
  <DNDSR-root>/build/app/euler3D.exe \
  <DNDSR-root>/cases/euler3D/euler3D_config_BenchTGV.json \
  -k /dataIOControl/meshFile -v '"<scratch>/UP3D_N.cgns"' \
  -k /dataIOControl/meshPartitionOptions/metisUfactor -v 30 \
  -k /dataIOControl/meshPartitionOptions/metisNcuts -v 1 \
  -k /dataIOControl/meshPartitionedWriter/type -v '"H5"' \
  -k /timeMarchControl/partitionMeshOnly -v true
```

| N | Source CGNS SHA-256 | HDF5 bytes | HDF5 SHA-256 | Mesh-coordinate hash |
|---:|---|---:|---|---|
| 161 | `2a05febf4f29de037343b7faf0da1d4f5a5c17232690d5f5bc9df1d3571e52ad` | 750521664 | `a0019b57562eeb59cda931efd5f6027a0ca7f430df68ae5e03407947e86917e6` | `b799eca5cc144af8` |
| 185 | `74164fdcb8cbf0b6b12b7315e480d10b9f258405bad2d2e80ce97ca13f0da1c7` | 1101015216 | `8a483ba8c00262a46bdd4fc2c4c9451fade950867c91bff4885947d1e7352a35` | `cd2042453aefb32c` |
| 194 | `5604cefe5f31ffc51b7e24537c726ac64f8fc7dc32816b10a1d746a37b788ca8` | 1255206680 | `aa72a03fb012cfb613db597a02ebe2ae0f8acbdfaa1c734f21b5382dcb21d93b` | `bfee87dd94accc01` |

The N=161 file was read locally with 8 ranks through `readMeshMode=2`, then
repartitioned with ParMetis and serialized again. That cross-rank check
completed with 4,173,281 global cells, a partition-size range of
505,240--527,135 cells (ratio 0.9585), and completed redistribution and face
interpolation. This verifies that the 64-way serialization is not tied to its
writer rank count.

## Submitted diagnostics

The first submissions on a8 and thtj1 stopped in the launcher before MPI
because it looked for the benchmark configuration inside each member
directory. The pending m8 counterpart was cancelled before allocation. The
launcher now takes the configuration as an explicit absolute input.

| Cluster | First job | First outcome | Corrected job |
|---|---:|---|---:|
| `bsscm8` | 4857269 | cancelled while pending | 4857297 |
| `bssca8` | 4857270 | launcher exit 1 | 4857296 |
| `thtj1` | 11822023 | launcher exit 1 | 11822048 |

Terminal outcomes and the acceptance decision are recorded in
[`RESULTS.md`](RESULTS.md) and [`results.csv`](results.csv). A failed setup run
is retained as diagnostic evidence but is never included in the parent weak
scaling throughput table.

[`bssc-ucx-no-knem.sh`](bssc-ucx-no-knem.sh) is a controlled transport
diagnostic for a BSSC repeat. It preserves PML UCX and the available
InfiniBand transports while excluding KNEM and XPMEM from intra-node transfer.
The original job is the baseline; this environment is not a new cluster
default.
