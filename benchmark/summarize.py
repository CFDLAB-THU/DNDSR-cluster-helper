#!/usr/bin/env python3
"""Summarize a completed DNDSR Euler3D benchmark log."""

from __future__ import annotations

import argparse
import json
import math
import re
import statistics
from pathlib import Path


TIMING = re.compile(
    r"BENCH iter=(?P<iter>\d+) telapsed=(?P<elapsed>[0-9.eE+-]+) "
    r"mean=(?P<mean>[0-9.eE+-]+) res=(?P<res>.*)"
)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("--cluster", required=True)
    parser.add_argument("--nodes", type=int, required=True)
    parser.add_argument("--ranks", type=int, required=True)
    parser.add_argument("--mesh-n", type=int, required=True)
    parser.add_argument("--first-iteration", type=int, default=101)
    parser.add_argument("--last-iteration", type=int, default=500)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    samples: dict[int, float] = {}
    last_residual = ""
    for line in args.log.read_text(errors="replace").splitlines():
        match = TIMING.search(line)
        if match:
            iteration = int(match.group("iter"))
            elapsed = float(match.group("elapsed"))
            if math.isfinite(elapsed) and elapsed > 0:
                samples[iteration] = elapsed
                last_residual = match.group("res")

    expected_count = args.last_iteration - args.first_iteration + 1
    selected = [
        samples[i]
        for i in range(args.first_iteration, args.last_iteration + 1)
        if i in samples
    ]
    if len(selected) != expected_count:
        raise SystemExit(
            f"expected {expected_count} timed samples for iterations "
            f"{args.first_iteration}..{args.last_iteration}, got {len(selected)}"
        )
    cells = args.mesh_n**3
    mean = statistics.fmean(selected)
    median = statistics.median(selected)
    stdev = statistics.stdev(selected)
    result = {
        "cluster": args.cluster,
        "nodes": args.nodes,
        "ranks": args.ranks,
        "mesh_n": args.mesh_n,
        "global_cells": cells,
        "cells_per_rank": cells / args.ranks,
        "warmup_iterations": [1, args.first_iteration - 1],
        "measured_iterations": [args.first_iteration, args.last_iteration],
        "sample_count": len(selected),
        "mean_iteration_seconds": mean,
        "median_iteration_seconds": median,
        "stdev_iteration_seconds": stdev,
        "coefficient_of_variation": stdev / mean,
        "max_iteration_seconds": max(selected),
        "mean_cell_iterations_per_second": cells / mean,
        "median_cell_iterations_per_second": cells / median,
        "last_residual_text": last_residual,
        "log": str(args.log),
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
