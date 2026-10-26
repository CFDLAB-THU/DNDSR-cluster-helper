---
name: cluster-setup
description: Set up or repair a cluster login using this repository's reviewed protocol, then record a sanitized cluster profile. Use for environment provisioning, not ordinary DNDSR execution.
---

# Cluster setup

Resolve the helper repository from this skill's location (three levels above
the skill directory). Read its `AGENTS.md`, `setup/README.md`, and selected
`cluster-<alias>/` profile. Keep the full protocol there rather than copying it.

Before remote changes, establish SSH alias, whether this is a new platform or
a second login to an existing platform, the user-supplied canonical DNDSR root
(normally `~/<name>/DNDSR`), HTTPS source URL, and desired source revision.
Never infer a personal workspace name. Homes, installed tools, scheduler
associations, and quotas belong to the login even on shared hardware.

Inspect and report effective Slurm account/QoS limits before setup: user and
visible parent associations, allowed/default QoS, CPU/TRES, submission/running
job and time limits, partition group access, and enforcement. Distinguish
QoS-level limits from association limits and report visibility gaps.

Select modules as an agent from live evidence. Follow the protocol's approval
gate for a new selection. An explicit request to reuse an already approved
platform setup permits revalidation of that setup for another login; it does
not approve an unreviewed compiler/MPI substitution. Probe compute CPUs before
compiler choice; validate compiler, assembler, C/C++ and MPI wrappers. Reject
Open MPI 4.1.0 for fresh DNDSR builds. Never silently switch to AOCC because an
MPI module depends on it; inspect wrapper commands and runtime library paths.
For an approved GCC build using an AOCC-default Open MPI module, persist
`OMPI_CC=gcc` and `OMPI_CXX=g++` in the fixed module layer, load GCC after the
module dependencies, and require GCC/G++ from both `--showme:command` checks
before externals, DNDSR or scheduled work. `CC=mpicc CXX=mpicxx` alone is not
sufficient to select the underlying compiler.

Use the guarded helpers only after fixing choices. Preserve existing startup
files, install all Bash/proxy helpers and the queue alias. For downloads, use
a cluster-provided proxy or a local SSH `-R` forwarded proxy, as supplied by
the operator. Do not prescribe a particular local proxy, endpoint or port.
Keep proxy settings scoped to the download session. Default to login-node builds with `JOBS=32` where this
protocol permits them, Pixi Ninja, uv-managed Python 3.12, `uv venv`, and
`uv pip install pip`. Read current DNDSR build/CI guidance for dependencies and
mesh URLs. Share canonical venv/externals; do not install DNDSR into the venv.
Build `eulerEX` and the C++ suite; setup excludes pybind and Python tests.

The common `setup/bash/.bashrc_utils.sh` owns the m8-style colored prompt,
history and aliases; keep modules in the login's `.bashrc_dndsr`. Validate
fresh interactive login/non-login shells and a `TERM=dumb` fallback. For a
prompt-only repair, back up and replace only the common helper; do not reset
the approved module environment or overwrite site/operator startup content.

Run finite scheduler smoke/tests within the actual login's limits. Validate
module/wrapper/library resolution inside jobs, collect exit/accounting and
application evidence, and distinguish submitted, building, queued, and passed.
Stop bounded retries on repeated infrastructure failures.

Produce `cluster-<alias>/README.md`, SSH access notes, fixed `env/modules.sh`,
reusable launch examples and the target description required by
`setup/target-description-template.md`. Separate inherited hardware evidence
from live observations. Keep login names, identity paths, personal source
paths, proxy ports, and raw evidence private. This skill allows profile edits
within the requested setup; commits/pushes require user authorization.
