#!/usr/bin/env bash
# Reviewed bsscm9 module and assembler selection, verified 2026-09-30.
source /publicfs10/fs10-share/soft/share-soft/modules/module.sh
module purge
module load cmake/3.30.2
module load gcc/14.2.0
module load openmpi/4.1.8-gcc14.2.0
export PATH="$HOME/.pixi/bin:$HOME/.local/bin:$PATH"
export PATH="$HOME/.local/dndsr-znver5-as/bin:$PATH"
alias sq="squeue -o \"%.12i %.9P %.80j %.8u %.2t %.10M %.6D %R\""
