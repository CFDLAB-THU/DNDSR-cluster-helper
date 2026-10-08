#!/usr/bin/env python3
"""Plot accepted weak-scaling throughput normalized by allocated MPI cores."""

from __future__ import annotations

import csv
from pathlib import Path
import sys

import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
from matplotlib.ticker import FuncFormatter


ROOT = Path(__file__).resolve().parent
REPOSITORY_ROOT = ROOT.parents[2]
sys.path.insert(0, str(REPOSITORY_ROOT / "scripts"))

from dndsr_pub_plot import (  # noqa: E402
    PublicationStyle,
    apply_publication_style,
    save_figure,
)

RESULTS = ROOT / "results" / "results.csv"
RETESTS = ROOT / "results" / "retests.csv"
OUTPUT = ROOT / "results" / "per-core-throughput.svg"
OUTPUT_PNG = ROOT / "results" / "per-core-throughput.png"

STYLE = PublicationStyle(
    figure_size=(10.2, 4.2),
    dpi=300,
    font_size=9,
    legend_font_size=8,
)

COLORS = {
    "bsscm8": STYLE.colors[0],
    "bsscm9": STYLE.colors[2],
    "bssca8": STYLE.colors[1],
    "thtj1": STYLE.colors[3],
}
LABELS = {
    "bsscm8": "m8",
    "bsscm9": "m9",
    "bssca8": "a8",
    "thtj1": "thtj1",
}


def read_rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="") as stream:
        return list(csv.DictReader(stream))


def per_core_kcell(row: dict[str, str], statistic: str) -> float:
    throughput = float(row[f"{statistic}_cell_iterations_per_second"])
    return throughput / float(row["ranks"]) / 1000.0


def main() -> None:
    production = read_rows(RESULTS)
    retests = read_rows(RETESTS)

    try:
        apply_publication_style(STYLE)
    except ModuleNotFoundError:
        apply_publication_style(STYLE, use_scienceplots=False)
    plt.rcParams["svg.fonttype"] = "none"
    fig, axes = plt.subplots(
        1,
        2,
        figsize=STYLE.figure_size,
        dpi=STYLE.dpi,
        sharex=True,
        sharey=True,
    )

    for ax, statistic, title in zip(
        axes,
        ("mean", "median"),
        ("Mean over iterations 101–500", "Median over iterations 101–500"),
    ):
        for cluster in COLORS:
            rows = sorted(
                (row for row in production if row["cluster"] == cluster),
                key=lambda row: int(row["ranks"]),
            )
            ax.plot(
                [int(row["ranks"]) for row in rows],
                [per_core_kcell(row, statistic) for row in rows],
                color=COLORS[cluster],
                marker="o",
                markersize=STYLE.marker_size,
                linewidth=STYLE.line_width,
                label=f"{LABELS[cluster]} production CGNS",
            )

        for cluster in ("bsscm8", "bssca8", "bsscm9"):
            rows = sorted(
                (row for row in retests if row["cluster"] == cluster),
                key=lambda row: int(row["ranks"]),
            )
            ax.plot(
                [int(row["ranks"]) for row in rows],
                [per_core_kcell(row, statistic) for row in rows],
                color=COLORS[cluster],
                marker="D",
                markerfacecolor="white",
                markersize=STYLE.marker_size + 1,
                linewidth=STYLE.line_width if len(rows) > 1 else 0,
                linestyle="--" if len(rows) > 1 else "none",
                label=f"{LABELS[cluster]} validated MPI + HDF5",
                zorder=4,
            )

        ax.set_xscale("log", base=2)
        ax.set_xlim(48, 9200)
        ax.set_ylim(bottom=0)
        ax.set_title(title)
        ax.set_xlabel("Physical CPU cores (one MPI rank/core)")
        ax.grid(True, which="major", alpha=STYLE.grid_alpha)
        ax.grid(True, which="minor", alpha=0.5 * STYLE.grid_alpha)
        ax.set_xticks([64, 128, 256, 512, 1024, 2048, 4096, 8192])
        ax.xaxis.set_major_formatter(FuncFormatter(lambda value, _: f"{int(value)}"))

    axes[0].set_ylabel("Throughput per core (kcell-iterations/s/core)")

    cluster_handles = [
        Line2D(
            [0],
            [0],
            color=COLORS[c],
            marker="o",
            linewidth=STYLE.line_width,
            label=LABELS[c],
        )
        for c in COLORS
    ]
    style_handles = [
        Line2D(
            [0],
            [0],
            color="#555555",
            marker="o",
            linewidth=STYLE.line_width,
            label="Production CGNS",
        ),
        Line2D(
            [0],
            [0],
            color="#555555",
            marker="D",
            markerfacecolor="white",
            linestyle="--",
            linewidth=STYLE.line_width,
            label="Validated MPI + HDF5",
        ),
    ]
    fig.legend(
        handles=cluster_handles + style_handles,
        loc="lower center",
        ncol=6,
        frameon=False,
        bbox_to_anchor=(0.5, -0.01),
    )
    fig.suptitle("Euler3D P3 weak-scaling throughput per physical CPU core", y=0.98)
    fig.tight_layout(rect=(0, 0.12, 1, 0.94))
    print(save_figure(fig, OUTPUT, style=STYLE))
    print(save_figure(fig, OUTPUT_PNG, style=STYLE, dpi=STYLE.dpi))


if __name__ == "__main__":
    main()
