#!/usr/bin/env bash
# Reviewed bsscm8 module triple, verified 2026-09-30.
source /publicfs01/fs1-share/soft/share-soft/modules/module.sh
module purge
module load cmake/4.1.1
module load gcc/14.2.0-a8-m8
module load mpi/openmpi/4.1.0-gcc14.2.0-a8-m8
export PATH="$HOME/.pixi/bin:$HOME/.local/bin:$PATH"
alias sq="squeue -o \"%.12i %.9P %.80j %.8u %.2t %.10M %.6D %R\""
