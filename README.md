# DNDSR cluster helper

Operational profiles and reusable launch examples for running DNDSR on shared
clusters. The repository is written for both automation agents and people. It
records scheduler and toolchain facts, safe operating practices, and generic
scripts without assuming a particular DNDSR checkout path, branch, case, or
study directory.

## Cluster profiles

- [`cluster-thtj1/`](cluster-thtj1/) — Slurm profile for `thtj1`, including
  the observed compiler/MPI environment, `debug6` compilation workflow,
  `cp6` production template, monitoring commands, and transfer guidance.
- [`cluster-bsscm8/`](cluster-bsscm8/) — reviewed GCC/Open MPI module triple,
  login-node build, CTest, and MPI launcher smoke examples.
- [`setup/`](setup/) — cluster-neutral, agent-driven setup protocol, including
  the module-selection approval gate.

Cluster facts age. Run the profile's inspection script before relying on node
counts, partition limits, module versions, or active wrapper paths.

## Intended use

1. Inspect the current cluster state without requesting an allocation.
2. Build an already configured DNDSR tree on the documented compilation
   partition.
3. Copy and specialize a production `sbatch` example into the study record.
4. Submit one intended production member and confirm solver progress before
   releasing a larger batch.
5. Preserve the rendered script, source/config hashes, job ID, logs, and final
   validation evidence.

The examples deliberately use environment variables for all project paths.
They should remain independent of any user's home directory or checkout name.
