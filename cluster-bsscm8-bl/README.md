# `bsscm8-bl`: separate login to M8

Inspection date: **2026-10-26**. This login shares the M8 platform with
[`bsscm8`](../cluster-bsscm8/) but has its own home and Slurm association.
The setup reuses the later validated Open MPI 5.0.10 runtime rather than the
historical Open MPI 4.1.0 default. Raw identities, paths and evidence stay in
the private setup record.

## SSH and allocation access

Use the operator-configured local alias `ssh bsscm8-bl`. The public gateway
is `ssh.cn-zhongwei-1.paracloud.com`, port 22. Obtain the cluster-qualified
login and identity from private operator configuration. No jump/proxy command
was configured; the inspected client uses a 45-second keepalive and disables
agent forwarding. For downloads, use a cluster-provided proxy or a local SSH
`-R` forwarded proxy supplied by the operator. Keep endpoints and ports private.

The association allows QoS `normal`, with no explicit default QoS,
`GrpTRES=cpu=192`, and `MaxSubmit=20`. The QoS record has no explicit
wall-time, CPU/TRES, running-job or submission caps; the user association
therefore imposes the observed 192-CPU and 20-submitted-job limits. Only the
user association was visible; unseen parent/site limits may further restrict
access. Group membership permits `amd_m8_768`, which is active and default.
It exposes 192 CPUs/node, 768,000 MB memory, default 4,000 MB/CPU and maximum
4,096 MB/CPU, with no reported partition wall-time maximum. All jobs still
request a finite limit. The broad `all` partition is inactive.

One exclusive full-node allocation consumes the observed CPU allowance.
Cross-node two-rank transport probes can request one CPU per node without
exclusive nodes. Full-node weak-scaling runs are limited to one node here.

## Selected environment

[env/modules.sh](env/modules.sh) loads CMake 4.1.1 and
`mpi/openmpi/5.0.10-gcc14.2.0-share`, which loads `gcc/14.2.0-share`.
Both MPI wrappers are explicitly set to GCC/G++ through `OMPI_CC`/`OMPI_CXX`.
Fresh inspection reports portable `-march=x86-64 -mtune=generic`; do not
infer defaults from the older M8 compiler-packaging failure. Compile/link and
compute probes must validate the actual current installation.

The canonical root and HTTPS source URL are supplied by the operator; public
examples use `SOURCE_DIR`, normally `~/<name>/DNDSR`. Login-node compilation
uses `JOBS=32`, Ninja for fresh build trees, and the canonical venv/externals.
The standard Bash helper provides the m8 prompt and the queue alias is kept
in the module layer. Setup validation covers C++ tests only, not DNDSR Python
package installation, pybind builds or Python-interface tests.

## Validation status

Fresh CPU and compile/link probes passed. Both same-node and cross-node
two-rank MPI transfers passed with Slurm exit `0:0`; observed transports and
the cross-node shutdown warning are recorded in [target.md](target.md).

The common Bash helpers, input settings and sourced proxy helpers are installed
with timestamped backups. Pixi 0.83.0, uv 0.13.5, Ninja 1.13.2, Doxygen 1.18.0,
and uv-managed Python 3.12.15 were verified. Ninja, Doxygen and uv are exposed
through Pixi global tools; the official uv installer is also retained.

The requested `origin/dev/harry` tip resolved to
`f080ba55627d93a7879ac59be172e25156644e76`. It was cloned over HTTPS without
configuring a Git identity or credentials. The source remains unchanged.
This exact revision has the same test-only portability issues as the A8
setup: `getpid` lacks `<unistd.h>` in `test_LocalChecks.cpp`, and
`all_unit_tests` omits the registered `euler_test_reactive_split_indicator`.
The [narrow CMake compatibility include](cmake/test-localchecks-compat.cmake)
adds the missing declaration to that test target only; the omitted target is
built explicitly. These workarounds are revision-specific, not global compiler
options.

All compiled externals, `eulerEX`, `all_unit_tests`, and the explicitly added
test executable built successfully with Ninja and `JOBS=32`. CMake identifies
GNU 14.2.0; `DNDS_DIST_MT_USE_OMP=OFF`. The executable links with
`-Wl,--exclude-libs,ALL`, and the reactive test does not export the guarded
Eigen sparse-resize symbol. `eulerEX` SHA-256:
`56431905f5d708aecc863394c4a3fa03de6b03b5c0a4c38faca55c1101380753`.

The externals revision is `942cf6700c2089669b66181b66de04a3ddaf7d54`, initial
CI meshes are `a5bba6f076ede1f9ba82219a8c4613b4481d3c7d`, and the header
archive SHA-256 is
`4550723d321fb31d3a1e52e5bb40b8e23fc8ae15f233d620f16b8139b9f38e4a`.
Source and externals remain clean after the build. The C++ suite completed on
one exclusive 192-CPU `amd_m8_768` node with QoS `normal`: **99 of 99 tests
passed** in 379.72 seconds. Slurm recorded `COMPLETED`, exit `0:0`, and a
6-minute-23-second allocation duration. Registered one-, two-, four- and
eight-rank MPI tests passed. The separate `tooling`-labelled Python regression
was excluded from setup's C++ validation; no DNDSR Python package, pybind
module or Python-interface tests were built/installed/run. C++ setup is complete.

Reusable fixed environment, build, MPI/transport and CTest examples are in
`env/`, `examples/`, and `cmake/`. The private dated setup record retains
rendered job scripts, job IDs, raw probe output, build/test logs and hashes.
