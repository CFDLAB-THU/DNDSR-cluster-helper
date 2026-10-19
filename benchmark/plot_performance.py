#!/usr/bin/env python3
"""Plot all comparable Euler3D P3 weak-scaling throughput records."""

from __future__ import annotations

import csv
from pathlib import Path
import sys

import matplotlib.pyplot as plt
from matplotlib.ticker import FuncFormatter


ROOT = Path(__file__).resolve().parent
REPOSITORY_ROOT = ROOT.parents[2]
sys.path.insert(0, str(REPOSITORY_ROOT / "scripts"))

from dndsr_pub_plot import (  # noqa: E402
    PublicationStyle,
    apply_publication_style,
    save_figure,
    series_encoding,
)


RESULTS = ROOT / "results" / "results.csv"
HDF5_RESULTS = ROOT / "results" / "hdf5-performance.csv"
OUTPUT_DIR = ROOT / "results"

STYLE = PublicationStyle(
    styles=("science", "no-latex"),
    figure_size=(7.2, 3.6),
    dpi=300,
    font_size=9.5,
    legend_font_size=8,
    target_markers=12,
)

CLUSTERS = ("bsscm8", "bssca8", "bsscm9", "thtj1")
LABELS = {
    "bsscm8": "m8",
    "bssca8": "a8",
    "bsscm9": "m9",
    "thtj1": "thtj1",
}
X_TICKS = (64, 128, 256, 512, 1024, 2048, 4096, 8192)
HDF5_LINE_STYLES = (
    (0, (5, 2)),
    (0, (3, 1, 1, 1)),
    (0, (1, 1)),
)


def read_rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="") as stream:
        return list(csv.DictReader(stream))


def rows_for(
    rows: list[dict[str, str]], cluster: str
) -> list[dict[str, str]]:
    return sorted(
        (row for row in rows if row["cluster"] == cluster),
        key=lambda row: int(row["ranks"]),
    )


def configure_core_axis(axis: plt.Axes) -> None:
    axis.set_xscale("log", base=2)
    axis.set_xlim(48, 9200)
    axis.set_xticks(X_TICKS)
    axis.xaxis.set_major_formatter(
        FuncFormatter(lambda value, _: f"{int(value)}")
    )
    axis.grid(True, which="major", alpha=STYLE.grid_alpha)
    axis.set_xlabel("Physical CPU cores")


def save_all_formats(figure: plt.Figure, stem: str) -> None:
    for extension in ("png", "pdf", "svg"):
        output = OUTPUT_DIR / f"{stem}.{extension}"
        print(save_figure(figure, output, style=STYLE, dpi=STYLE.dpi))
        if extension == "svg":
            cleaned = "\n".join(
                line.rstrip() for line in output.read_text().splitlines()
            )
            output.write_text(f"{cleaned}\n")


def plot_weak_scaling(production: list[dict[str, str]]) -> None:
    figure, axes = plt.subplots(
        1,
        2,
        figsize=STYLE.figure_size,
        dpi=STYLE.dpi,
    )

    for cluster_index, cluster in enumerate(CLUSTERS):
        rows = rows_for(production, cluster)
        encoding = series_encoding(cluster_index, len(rows), style=STYLE)
        ranks = [int(row["ranks"]) for row in rows]
        axes[0].plot(
            ranks,
            [float(row["mean_cell_iterations_per_second"]) / 1.0e6 for row in rows],
            label=LABELS[cluster],
            **encoding,
        )
        axes[1].plot(
            ranks,
            [100.0 * float(row["mean_weak_scaling_efficiency"]) for row in rows],
            label=LABELS[cluster],
            **encoding,
        )

    for axis in axes:
        configure_core_axis(axis)

    axes[0].set_yscale("log", base=2)
    axes[0].set_ylim(0.4, 40.0)
    axes[0].set_yticks((0.5, 1, 2, 4, 8, 16, 32))
    axes[0].yaxis.set_major_formatter(
        FuncFormatter(lambda value, _: f"{value:g}")
    )
    axes[0].set_ylabel(
        r"Mean throughput [$10^6$ cell-iterations s$^{-1}$]"
    )
    axes[0].set_title("Throughput")

    axes[1].set_ylim(0.0, 115.0)
    axes[1].set_ylabel("Mean weak-scaling efficiency [%]")
    axes[1].set_title("Efficiency")

    handles, labels = axes[0].get_legend_handles_labels()
    figure.legend(
        handles,
        labels,
        loc="lower center",
        ncol=4,
        frameon=False,
        bbox_to_anchor=(0.5, -0.01),
    )
    figure.tight_layout(rect=(0, 0.12, 1, 1))
    save_all_formats(figure, "weak-scaling")
    plt.close(figure)


def per_core_kcell(row: dict[str, str], statistic: str) -> float:
    throughput = float(row[f"{statistic}_cell_iterations_per_second"])
    return throughput / float(row["ranks"]) / 1000.0


def plot_per_core(
    production: list[dict[str, str]],
    hdf5_results: list[dict[str, str]],
) -> None:
    comparable_hdf5 = [
        row
        for row in hdf5_results
        if row["comparison_class"] == "weak-scaling-compatible"
    ]
    figure, axes = plt.subplots(
        1,
        2,
        figsize=STYLE.figure_size,
        dpi=STYLE.dpi,
        sharex=True,
        sharey=True,
    )

    for axis, statistic, title in zip(
        axes,
        ("mean", "median"),
        ("Mean", "Median"),
    ):
        for cluster_index, cluster in enumerate(CLUSTERS):
            rows = rows_for(production, cluster)
            encoding = series_encoding(cluster_index, len(rows), style=STYLE)
            axis.plot(
                [int(row["ranks"]) for row in rows],
                [per_core_kcell(row, statistic) for row in rows],
                label=f"{LABELS[cluster]} CGNS",
                **encoding,
            )

        for hdf_index, cluster in enumerate(CLUSTERS[:3]):
            rows = rows_for(comparable_hdf5, cluster)
            encoding = series_encoding(4 + hdf_index, len(rows), style=STYLE)
            cluster_color = STYLE.colors[hdf_index]
            encoding.update(
                color=cluster_color,
                markeredgecolor=cluster_color,
                linestyle=HDF5_LINE_STYLES[hdf_index],
            )
            if len(rows) == 1:
                encoding.update(linestyle="none", linewidth=0)
            axis.plot(
                [int(row["ranks"]) for row in rows],
                [per_core_kcell(row, statistic) for row in rows],
                label=f"{LABELS[cluster]} HDF5/new MPI",
                zorder=4,
                **encoding,
            )

        configure_core_axis(axis)
        axis.set_ylim(bottom=0)
        axis.set_title(title)

    axes[0].set_ylabel(
        r"Per-core throughput [kcell-iterations s$^{-1}$ core$^{-1}$]"
    )

    handles, labels = axes[0].get_legend_handles_labels()
    figure.legend(
        handles,
        labels,
        loc="lower center",
        ncol=4,
        frameon=False,
        bbox_to_anchor=(0.5, -0.05),
    )
    figure.tight_layout(rect=(0, 0.18, 1, 1))
    save_all_formats(figure, "per-core-throughput")
    plt.close(figure)


def main() -> None:
    try:
        apply_publication_style(STYLE)
    except ModuleNotFoundError:
        apply_publication_style(STYLE, use_scienceplots=False)
    plt.rcParams["svg.fonttype"] = "none"

    production = read_rows(RESULTS)
    hdf5_results = read_rows(HDF5_RESULTS)
    plot_weak_scaling(production)
    plot_per_core(production, hdf5_results)


if __name__ == "__main__":
    main()
