# AGENTS.md — DNDSR cluster helper

This repository contains public operational documentation and generic examples.
Keep every file free of credentials, private keys, tokens, account names,
personal home paths, unpublished data paths, and checkout-specific state.

## Before changing a cluster profile

1. Re-query the live scheduler, compiler wrappers, runtime versions, and module
   list. Mark observations with a date and distinguish them from stable rules.
2. Use read-only, allocation-free inspection for dry runs. Do not invoke
   `srun`, `salloc`, `sbatch`, MPI, or a solver merely to validate a script.
3. Avoid compilation or computation on login nodes. Use the cluster profile's
   documented build partition and allocation.
4. Keep examples generic. Use variables such as `SOURCE_DIR`, `BUILD_DIR`,
   `EXECUTABLE`, `CONFIG`, and `RUN_DIR`; never bake in a user's checkout.
5. Run `bash -n` on shell examples and `git diff --check` before committing.

## Submission discipline

- Materialize a run-specific copy of an example and preserve it with the run
  record.
- State nodes, tasks, CPUs per task, memory/GPU needs, partition, and wall time
  explicitly.
- Keep `OMP_NUM_THREADS` consistent with `--cpus-per-task`.
- For a campaign, submit one intended production member first. Confirm from
  scheduler state and application output that it entered the solver and is
  progressing normally before submitting the rest.
- Never infer success from a job disappearing from `squeue`; inspect `sacct`,
  the application log, the exit code, final-step evidence, and output files.
- Do not cancel, requeue, submit, create repositories, commit, or push unless
  the user has authorized that action.

## Documentation style

Write commands that can be copied safely, explain why cluster-specific
environment variables are needed, and call out version or module discrepancies.
Do not present queue size, node state, or filesystem speed as permanent facts.
