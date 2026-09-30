# Cluster setup chain

This directory records a cluster-neutral, agent-driven setup procedure. At each
stage, inspect current state, choose from the evidence, apply that reviewed
choice, and record the result under `cluster-<alias>/`. Do not delegate module
selection, checkout reconciliation, or scheduler resource selection to a
discovery script.

A completed setup always produces a public, sanitized `cluster-<alias>/`
description. Use [`target-description-template.md`](target-description-template.md)
as its minimum content: compute-node CPU and `lscpu` topology, memory/NUMA,
network hardware, UCX availability, MPI build components, runtime-selected
intra- and inter-node transfer backends, scheduler behavior, the approved
toolchain, and build/test evidence. Installed MPI components and the component
selected at runtime must be reported separately.

## Module-selection approval gate

For each new cluster, the agent first gathers the selection evidence below and
reports the exact CMake, GCC, and MPI module names, the MPI wrapper's underlying
compiler, and any module-label versus runtime-version discrepancy. The agent
must then wait for the operator to confirm that selection before changing shell
startup files, installing tools, cloning source, or starting the DNDSR build.
Approval for one cluster does not carry over to another.

The read-only and disposable checks used to prepare the approval packet are:

1. Obtain a small allocation on the intended CPU partition and record `lscpu`,
   `/proc/cpuinfo` model name and flags, node identity, and Slurm CPU topology.
   CPU evidence comes before compiler choice; do not infer compute-node ISA
   from the login node or from a cluster/module name.
2. Inspect candidate modulefiles and record their paths and dependencies. Load
   one fixed CMake/GCC/Open MPI triple, then record `module list`, resolved
   executable paths, versions, `gcc -Q --help=target` values for `-march` and
   `-mtune`, assembler version, `mpicc --showme:version`, and
   `mpicc --showme:command`.
3. Compile minimal C, C++, MPI C, and MPI C++ translation units with warnings
   enabled. Preserve command lines and compiler diagnostics. Inspect the
   resulting objects/executables and reject a candidate on any assembler,
   linker, runtime-library, or wrapper/compiler mismatch.
4. Run the MPI smoke under Slurm with two ranks. Each rank must report the
   expected size, unique rank, compute host, and loaded-library resolution.
   A login-node compile alone does not validate compute-node execution.
5. Present this evidence and the proposed fixed module triple for confirmation.
   After confirmation, reproduce the exact choice in shell startup and setup
   records; do not let a script discover or substitute modules.

After that explicit per-cluster confirmation, continue with the setup chain:

1. Inspect modules and Slurm. The agent selects CMake, GCC, and an Open MPI 4.1 module
   annotated with that GCC version. Verify the actual MPI wrappers, not only
   the module label. Save the load commands in `~/.bashrc_dndsr`.
2. The agent compares the reference host and installs `~/.bashrc_utils.sh`,
   `~/.bashrc_dndsr`, and `~/.inputrc` from reviewed templates. Preserve
   existing files with timestamped backups. Install `~/.setproxy.sh` and
   `~/.unsetproxy.sh` as sourced helpers. The interactive startup must source
   `~/.bashrc_dndsr`. Keep proxy exports out of persistent startup files; proxy
   state belongs only to the foreground forwarded session. Every
   `.bashrc_dndsr` install includes:

   ```bash
   alias sq="squeue -o \"%.12i %.9P %.80j %.8u %.2t %.10M %.6D %R\""
   ```
3. Install Pixi and uv using their official curl installers. Use Pixi global
   installs for Ninja and other standalone build tools. Install Python 3.12
   with `uv python install 3.12 --default` so `python3` also resolves to the
   uv-managed interpreter, create the DNDSR environment with
   `uv venv --python 3.12 venv`, then install pip into it with
   `uv pip install --python venv/bin/python pip` before following DNDSR's
   dependency guide.
   Keep proxy exports confined to the current shell. Start a foreground SSH
   session with ephemeral forwarding:

   ```bash
   ssh -o ExitOnForwardFailure=yes -R <proxy-port>:127.0.0.1:<proxy-port> "$CLUSTER"
   export LOCAL_PROXY_PORT=<proxy-port>
   source ~/.setproxy.sh
   # The agent now runs the reviewed official installer commands in this shell.
   ```

   Close this SSH session when downloads are finished. Do not use `ssh -f`,
   `autossh`, a service, or a persistent tunnel: subsequent logins may land
   on a different node. Do not forward proxy settings into compute jobs.
4. The agent inspects the requested checkout path. If absent, clone from the
   operator-supplied HTTPS source URL into `~/<name>/DNDSR` by default. Here,
   `<name>` is an operator-chosen workspace name and is never a hard-coded
   personal directory. If present, reconcile its source state before changing
   it. Do not configure a Git
   identity or credentials on the shared Linux account. Fetch submodules,
   header-only dependencies, and build requirements while forwarding exists.
   Obtain the initial test meshes from the mesh repository used by the current
   DNDSR `.github/workflows/ci.yml`; resolve its HTTPS URL at execution time and
   do not copy personal fork or home-path details into this repository.
5. Configure fresh build trees with Ninja, then compile externals, `eulerEX`,
   and `all_unit_tests` on the login node with `JOBS=32`. An established build
   tree keeps its existing generator. Preserve a full build log, and do not
   export proxy variables during compilation. Use Slurm for C++ tests and MPI
   launcher smoke tests so runtime behavior is checked on compute nodes.
   Capture build exit status, scheduler accounting, test summaries, and
   executable hashes before claiming success. Setup validation ends with the
   C++ suite: do not build or install DNDSR pybind modules and do not run Python
   tests during this phase.

   On GNU/Linux, configure executables with
   `-DCMAKE_EXE_LINKER_FLAGS=-Wl,--exclude-libs,ALL`. DNDSR's header archive
   currently provides Eigen 5 while Cantera builds its bundled Eigen 3.4;
   hiding symbols pulled from DNDSR's static archives prevents its inline Eigen
   functions from interposing on Cantera's private Eigen objects. After linking,
   verify that the reactive C++ test does not dynamically export
   `Eigen::SparseMatrix<double, 0, int>::resize`.
6. Generate or update `cluster-<alias>/README.md`, its fixed `env/modules.sh`,
   and reusable build/MPI/Test examples. Summarize the target using the template
   above and link each conclusion to a dated private evidence file. The public
   profile is an output of setup, not optional follow-up documentation.

## Guarded reusable steps

The scripts under `examples/` reproduce the mechanical parts after the agent
has selected modules and the operator has approved them:

1. `verify-approved-toolchain.sh` checks resolved tools and versions, compiler
   defaults, four C/C++ and MPI compile/link paths, and MPI library resolution.
2. `install-shell-layer.sh` backs up and installs `.bashrc_utils.sh`,
   `.bashrc_dndsr`, `.inputrc`, and both proxy helpers. It rejects a module
   layer that omits the exact `sq` alias.
3. `install-tools.sh` requires an active local-only forwarded proxy, runs the
   official Pixi and uv installers, installs Ninja and Doxygen with Pixi,
   installs Python 3.12 as the uv-managed default, and verifies every command.
4. `prepare-and-build-dndsr.sh` requires the CI-resolved header and mesh URLs,
   creates the venv with `uv venv`, installs pip with `uv pip`, installs the
   external builder's Python requirements, initializes submodules and meshes,
   builds compiled externals, configures Ninja for a fresh tree, and builds
   `eulerEX` plus `all_unit_tests` with `JOBS=32` by default. It also applies
   and verifies the executable symbol-isolation guard required by the current
   DNDSR/Cantera Eigen versions.
5. The cluster profile's Slurm examples then validate rank launch and runtime
   MPI transport on compute nodes and run `ctest -E '^pytest_'`. Setup ends with
   C++ tests; pybind builds, package installation, and Python tests are later
   work.

Keep raw records in the operator's private run directory. Publish only
sanitized results under `cluster-<alias>/`; raw login banners, Git remotes,
module output, and Slurm accounting can contain shared account identifiers.

Installer references: [Pixi](https://pixi.sh/latest/installation/),
[uv](https://docs.astral.sh/uv/getting-started/installation/).
