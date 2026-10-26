# `bssca8-bl`: separate login to the A8 cluster

Inspection date: **2026-10-26**. This alias reaches the same A8 platform as
[`bssca8`](../cluster-bssca8/), with a separate Linux login, home directory,
and scheduler association. Installed files and allocation limits do not carry
over between the logins.

## SSH access

Use `ssh bssca8-bl` with the operator's existing local SSH configuration.
The public gateway is `ssh.cn-zhongwei-1.paracloud.com`, port 22. The gateway
login includes a site/cluster suffix; obtain the full login from the operator
rather than constructing it from the remote Linux username. No jump host was
configured at inspection; agent forwarding was disabled, and the local client
used a 45-second keepalive. Keep identity paths and login strings private.

For downloads, use a foreground session only:

```bash
ssh -o ExitOnForwardFailure=yes \
  -R <proxy-port>:127.0.0.1:<proxy-port> bssca8-bl
export LOCAL_PROXY_PORT=<proxy-port>
source ~/.setproxy.sh
```

The reverse-forward destination is on the SSH client. Reopen the tunnel for
each download session because logins may route to different nodes. Do not
create persistent forwarding or export proxy settings into compute jobs.

## Slurm allocation access

The live user association permits QoS **`normal`**, with no explicit default
QoS, **`GrpTRES=cpu=128`**, and **`MaxSubmit=20`**. These are association
limits, not QoS-wide limits: at most 128 CPUs may be allocated concurrently
under this association, and at most 20 jobs may be submitted at once. The
`normal` QoS record has no explicit wall-time or TRES/job caps. Slurm enforces
`associations,limits,qos`. The query exposed only this user's association;
unseen parent-account or site limits may impose additional restrictions.

The login belongs to the access groups for `amd_a8_384` and `amd_a8_768`.
Both partitions are active, with 128 scheduled CPUs per node. Prefer the
normal `amd_a8_384` partition: default 3,000 MB/CPU, maximum 3,072 MB/CPU.
The large-memory partition has default 6,000 MB/CPU and maximum 6,144 MB/CPU.
The broad `all` partition is inactive. No partition wall-time maximum was
reported; every example must still request a finite time.

One full-node allocation consumes the entire observed 128-CPU allowance.
Do not copy the other login's multi-node benchmark requests. A two-node
transport test can request one rank per node without exclusive full nodes,
but only after checking current access and capacity. Full-node weak-scaling
benchmarks remain limited to one node by this association.

## Toolchain and setup status

The selected environment is [env/modules.sh](env/modules.sh): CMake 4.1.1,
GCC 14.2.0, and the proven A8 Open MPI 4.1.6/AOCC 5 runtime. The MPI module
loads AOCC; fresh GCC builds explicitly export `OMPI_CC=gcc` and
`OMPI_CXX=g++`, with GCC loaded last. Compiler defaults are portable
`-march=x86-64 -mtune=generic`; system assembler is binutils 2.30.

Login-node MPI C/C++ compilation passed. The C++ binary resolves Open MPI
4.1.6 and GCC 14's `libstdc++`, with no missing libraries. UCX is 1.14.0.
The original A8 Open MPI 4.1.0 stack is historical failure evidence and must
not be selected for a new DNDSR build.

Other live GCC-labelled variants are `mpi/openmpi/4.1.1-gcc9.5.0`,
`mpi/openmpi/4.1.0-gcc14.2.0`, and `mpi/openmpi/4.1.0-gcc8.5.0`. The first
loads GCC 9.5 and reports GCC/G++ wrapper commands without overrides; it has
not been validated with this DNDSR setup. The two 4.1.0 variants remain
unsuitable. No newer GCC-labelled Open MPI module appeared in the inspected
A8 catalog. Do not confuse a verified catalog entry with a passed application
test or silently replace the selected stack.

Fresh compute probes under this login confirm the dual EPYC 9554 / 128-core
Zen 4 target and a successful two-node 2 MiB MPI transfer using UCX
`rc_mlx5`. See [target.md](target.md) for details and limitations.

The shell layer installs `.bashrc_utils.sh`, `.bashrc_dndsr`, `.inputrc`,
`.setproxy.sh`, and `.unsetproxy.sh`, preserves the queue alias, and advertises
`source ~/.bashrc_dndsr` for interactive use. Pixi 0.83.0, uv 0.13.5, Ninja
1.13.2, Doxygen 1.18.0, and uv-managed Python 3.12.15 were installed and
verified. Ninja, Doxygen and uv are available through Pixi global tools;
the official uv curl installation is also retained.

On **2026-10-26**, the shared Bash helper was updated with m8's green
`user@host` and blue working directory prompt, preserving a timestamped backup.
Fresh interactive login/non-login shells matched m8's `PS1` for
`TERM=xterm-256color`; plain-terminal and noninteractive guards also passed.
The common template in `setup/bash/` is authoritative for future shell installs.

The requested `origin/dev/harry` tip resolved to
`f080ba55627d93a7879ac59be172e25156644e76`. The source was cloned read-only
over HTTPS at this revision without configuring a Git account or credentials.
Compiled externals and the Ninja `eulerEX all_unit_tests` build passed with
GCC 14.2 and `JOBS=32`; `DNDS_DIST_MT_USE_OMP=OFF`. The `eulerEX` SHA-256 is
`5e99d9ad49bf230b0ac320b8ed600ac3fbdb19f2edbc16ee33b00d6fe2c45c3b`.
The reactive test does not dynamically export the guarded Eigen resize symbol.
The externals revision is `942cf6700c2089669b66181b66de04a3ddaf7d54`;
initial CI meshes were fetched at `a5bba6f076ede1f9ba82219a8c4613b4481d3c7d`.
The header archive SHA-256 is
`4550723d321fb31d3a1e52e5bb40b8e23fc8ae15f233d620f16b8139b9f38e4a`.

This source revision's `test_LocalChecks.cpp` omits `<unistd.h>` for `getpid`.
The first build failed there. A narrowly scoped build-only include workaround
in [cmake/test-localchecks-compat.cmake](cmake/test-localchecks-compat.cmake)
was passed through `CMAKE_PROJECT_TOP_LEVEL_INCLUDES`, preserving source files
and the exact revision. Do not apply it automatically to newer revisions.
The first CTest allocation used one exclusive `amd_a8_384` node with QoS
`normal` and finished in 344.68 seconds: 98 of 100 entries passed. The tooling
test's synthetic MPI-release guard check failed, and
`euler_reactive_split_indicator` was not run because this revision's
`all_unit_tests` target omitted its executable. That executable has since been
built explicitly and passed its focused Slurm check in 0.13 seconds with
exit `0:0`. Thus **all 99 C++ entries passed across the two allocations**.
The separate Python tooling regression remains failed and is not counted as
a C++ pass. The C++ setup validation is complete with the two revision-specific
build workarounds documented above. No DNDSR pybind or Python-interface tests
were run.

AOCC/GCC runtime observations and mixed-compiler conditions are recorded in
[compiler-abi.md](compiler-abi.md). The active setup compiles with GCC.

The canonical root is supplied by the operator and kept in private records.
Public commands use `SOURCE_DIR`, normally `~/<name>/DNDSR`. Compilation uses
the login node with `JOBS=32`, fresh Ninja trees, and shared canonical venv and
externals. Setup ends with C++ tests; no DNDSR Python package installation.
