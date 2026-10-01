#!/usr/bin/env python3
"""Generate a uniform N^3 periodic HEX_8 CGNS mesh on [0, 1]^3."""

from __future__ import annotations

import argparse
import ctypes
from pathlib import Path

import numpy as np


CG_MODE_WRITE = 1
UNSTRUCTURED = 3
QUAD_4 = 7
HEXA_8 = 17
REAL_DOUBLE = 4
BC_TYPE_NULL = 0
POINT_RANGE = 4
FACE_CENTER = 4

cgsize_t = ctypes.c_long


def load_cgns(repo_root: Path) -> ctypes.CDLL:
    path = repo_root / "external/cfd_externals/install/lib/libcgns.so"
    lib = ctypes.CDLL(str(path), mode=ctypes.RTLD_GLOBAL)
    lib.cg_get_error.restype = ctypes.c_char_p
    lib.cg_open.argtypes = [ctypes.c_char_p, ctypes.c_int, ctypes.POINTER(ctypes.c_int)]
    lib.cg_close.argtypes = [ctypes.c_int]
    lib.cg_base_write.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_int, ctypes.POINTER(ctypes.c_int)]
    lib.cg_zone_write.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_char_p, ctypes.POINTER(cgsize_t), ctypes.c_int, ctypes.POINTER(ctypes.c_int)]
    lib.cg_coord_write.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_char_p, ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_int)]
    lib.cg_section_write.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_char_p, ctypes.c_int, cgsize_t, cgsize_t, ctypes.c_int, ctypes.POINTER(cgsize_t), ctypes.POINTER(ctypes.c_int)]
    lib.cg_boco_write.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_int, cgsize_t, ctypes.POINTER(cgsize_t), ctypes.POINTER(ctypes.c_int)]
    lib.cg_boco_gridlocation_write.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int]
    return lib


def check(lib: ctypes.CDLL, status: int, operation: str) -> None:
    if status:
        error = lib.cg_get_error()
        detail = error.decode(errors="replace") if error else "unknown error"
        raise RuntimeError(f"{operation}: {detail}")


def cgptr(array: np.ndarray) -> ctypes.POINTER(cgsize_t):
    return array.ctypes.data_as(ctypes.POINTER(cgsize_t))


def dptr(array: np.ndarray) -> ctypes.POINTER(ctypes.c_double):
    return array.ctypes.data_as(ctypes.POINTER(ctypes.c_double))


def generate(repo_root: Path, output: Path, n: int) -> None:
    lib = load_cgns(repo_root)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.unlink(missing_ok=True)

    nn = n + 1

    def node(i: np.ndarray, j: np.ndarray, k: np.ndarray) -> np.ndarray:
        return ((k * nn + j) * nn + i + 1).astype(np.int64, copy=False)

    k, j, i = np.meshgrid(
        np.arange(nn, dtype=np.int64),
        np.arange(nn, dtype=np.int64),
        np.arange(nn, dtype=np.int64),
        indexing="ij",
    )
    coordinates = [
        np.ascontiguousarray(i.ravel() / n, dtype=np.float64),
        np.ascontiguousarray(j.ravel() / n, dtype=np.float64),
        np.ascontiguousarray(k.ravel() / n, dtype=np.float64),
    ]

    ck, cj, ci = np.meshgrid(
        np.arange(n, dtype=np.int64),
        np.arange(n, dtype=np.int64),
        np.arange(n, dtype=np.int64),
        indexing="ij",
    )
    cells = np.column_stack(
        [
            node(ci, cj, ck).ravel(),
            node(ci + 1, cj, ck).ravel(),
            node(ci + 1, cj + 1, ck).ravel(),
            node(ci, cj + 1, ck).ravel(),
            node(ci, cj, ck + 1).ravel(),
            node(ci + 1, cj, ck + 1).ravel(),
            node(ci + 1, cj + 1, ck + 1).ravel(),
            node(ci, cj + 1, ck + 1).ravel(),
        ]
    ).astype(np.int64, copy=False)
    cells = np.ascontiguousarray(cells.ravel())

    a, b = np.meshgrid(
        np.arange(n, dtype=np.int64),
        np.arange(n, dtype=np.int64),
        indexing="ij",
    )
    zero = np.zeros_like(a)
    high = np.full_like(a, n)

    def quads(vertices: list[np.ndarray]) -> np.ndarray:
        return np.ascontiguousarray(
            np.column_stack([v.ravel() for v in vertices]).ravel(),
            dtype=np.int64,
        )

    boundaries = [
        ("PERIODIC_1", quads([node(zero, a, b), node(zero, a + 1, b), node(zero, a + 1, b + 1), node(zero, a, b + 1)])),
        ("PERIODIC_1_DONOR", quads([node(high, a, b), node(high, a, b + 1), node(high, a + 1, b + 1), node(high, a + 1, b)])),
        ("PERIODIC_2", quads([node(a, zero, b), node(a, zero, b + 1), node(a + 1, zero, b + 1), node(a + 1, zero, b)])),
        ("PERIODIC_2_DONOR", quads([node(a, high, b), node(a + 1, high, b), node(a + 1, high, b + 1), node(a, high, b + 1)])),
        ("PERIODIC_3", quads([node(a, b, zero), node(a + 1, b, zero), node(a + 1, b + 1, zero), node(a, b + 1, zero)])),
        ("PERIODIC_3_DONOR", quads([node(a, b, high), node(a, b + 1, high), node(a + 1, b + 1, high), node(a + 1, b, high)])),
    ]

    fn = ctypes.c_int()
    check(lib, lib.cg_open(str(output).encode(), CG_MODE_WRITE, ctypes.byref(fn)), "cg_open")
    try:
        base = ctypes.c_int()
        zone = ctypes.c_int()
        section = ctypes.c_int()
        coord = ctypes.c_int()
        bc = ctypes.c_int()
        check(lib, lib.cg_base_write(fn.value, b"Base", 3, 3, ctypes.byref(base)), "cg_base_write")
        sizes = np.array([nn**3, n**3, 0], dtype=np.int64)
        check(lib, lib.cg_zone_write(fn.value, base.value, b"Zone", cgptr(sizes), UNSTRUCTURED, ctypes.byref(zone)), "cg_zone_write")
        for name, values in zip((b"CoordinateX", b"CoordinateY", b"CoordinateZ"), coordinates, strict=True):
            check(lib, lib.cg_coord_write(fn.value, base.value, zone.value, REAL_DOUBLE, name, dptr(values), ctypes.byref(coord)), name.decode())

        first = 1
        last = n**3
        check(lib, lib.cg_section_write(fn.value, base.value, zone.value, b"HexElements", HEXA_8, first, last, 0, cgptr(cells), ctypes.byref(section)), "HexElements")
        first = last + 1
        for name, connectivity in boundaries:
            last = first + n * n - 1
            check(lib, lib.cg_section_write(fn.value, base.value, zone.value, name.encode(), QUAD_4, first, last, 0, cgptr(connectivity), ctypes.byref(section)), name)
            points = np.array([first, last], dtype=np.int64)
            check(lib, lib.cg_boco_write(fn.value, base.value, zone.value, name.encode(), BC_TYPE_NULL, POINT_RANGE, 2, cgptr(points), ctypes.byref(bc)), f"BC {name}")
            check(lib, lib.cg_boco_gridlocation_write(fn.value, base.value, zone.value, bc.value, FACE_CENTER), f"BC location {name}")
            first = last + 1
    finally:
        check(lib, lib.cg_close(fn.value), "cg_close")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--n", type=int, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    generate(args.repo.resolve(), args.output.resolve(), args.n)
    print(args.output.resolve())


if __name__ == "__main__":
    main()
