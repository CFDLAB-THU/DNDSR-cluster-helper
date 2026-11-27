# Cross-building Cauchy for the BSSC clusters

Use a separate private directory for each **cluster, architecture and toolchain**. The workstation can build the whole CPU executable from source. For GPU targets, it can compile production LVR device code from source and separately relink an existing target-native solver. The GPU relink reuses the captured host and device-link objects. Source edits require rebuilding the affected objects, including the CUDA device link where applicable.

## Target selection

The following selections were checked on the login hosts on 2026-11-27. Load the same profile when collecting inputs and checking the executable.

| Target and profile | Target host and GCC | MPI | Device compiler / target | NCCL |
|---|---|---|---|---|
| [BSSCA](../cluster-bssca/env/ucx410.sh) | x86-64, glibc 2.17, GCC 12.2 | Open MPI 4.1.0-para / UCX | CPU | — |
| [A8-BL](../cluster-bssca8-bl/env/modules.sh) | x86-64, glibc 2.28, GCC 14.2 | Open MPI 4.1.6, built with AOCC, GCC wrappers | CPU | — |
| [M8-BL](../cluster-bsscm8-bl/env/modules.sh) | x86-64, glibc 2.28, GCC 14.2 | Open MPI 5.0.10 | CPU | — |
| [N32](../cluster-bsscn32h/env/modules.sh) | AArch64, GCC 13.2 | HPC-X 2.50 / Open MPI 5.0.10rc2 | CUDA 12.8 / A100 SM80 | Site 2.26.5 |
| [N46](../cluster-bsscn46h1/env/modules.sh) | x86-64, GCC 14.2 | HPC-X 2.25.1 / Open MPI 4.1.9a1 | CUDA 13.0 / A800 SM80 | 2.27.3. For Hopper SM90 select the profile's 2.28.9 variant. |
| [N56](../cluster-bsscn56r5/env/modules.sh) | x86-64, GCC 14.2 | HPC-X 2.25.1 / Open MPI 4.1.9a1 | CUDA 13.0 / RTX 4090 SM89 and 5090 SM120 | 2.28.9 from the site prefix containing both architectures |

## CPU solver from source

On the target, initialize its module command, set `MODULE_ENV` to the **target-side** profile and `EXTERNALS_PREFIX` to a populated installation of the scientific libraries built with that MPI. Run the capture script from a copy of this repository. Keep site paths and binary captures private.

```bash
# Target login
export MODULE_ENV EXTERNALS_PREFIX
bash cross-build/capture-cpu.sh > "$CAPTURE_DIR/cpu-sysroot.tar.gz"
sha256sum "$CAPTURE_DIR/cpu-sysroot.tar.gz"
```

Transfer the archive to the x86-64 workstation, verify its SHA-256 and unpack it into an empty directory. It contains the target headers, glibc/GCC startup objects, MPI, scientific libraries and GCC frontends, plus a small manifest with paths relative to the captured root. The build needs host binutils, Ninja, CMake and Python development headers. Use a source checkout with populated header dependencies.

```bash
# Workstation
export SOURCE_DIR BUILD_DIR TARGET_SYSROOT JOBS
mkdir -p "$TARGET_SYSROOT"
tar -xzf cpu-sysroot.tar.gz -C "$TARGET_SYSROOT"
bash cross-build/configure-cpu.sh
# For the BSSCA 4.1.0-para profile use this invocation instead
# bash cross-build/configure-cpu.sh -DDNDS_ALLOW_OPENMPI_410=ON
```

The compiler wrapper isolates host-executable compiler dependencies from the target libc. It explicitly selects the target C++ headers and startup objects, and uses generic x86-64 instructions. CMake resolves MPI and scientific libraries inside the sysroot. Host Python satisfies configure-time discovery for this solver-only build. Set `CONFIGURE_ONLY=1` to stop after generation. Rerun the wrapper script for incremental builds so the compiler sees the same environment.

## GPU device code and host executable

1. **Compile a production device translation unit.** On the x86-64 workstation, select an x86-64 nvcc matching the target toolkit family, a supported host compiler and the checkout's dependency headers. For N32 the GPU target is SM80 even though its host is AArch64. The cubin contains device code only.

   ```bash
   export CUDA_HOME SOURCE_DIR CUDAHOSTCXX
   bash cross-build/build-lvr-cubin.sh 80 lvr-sm80.cubin
   # For N56 with CUDA 13.0, repeat for 89 and 120.
   ```

2. **Capture a matching native build.** Under the target profile, expose the native build's AmgX and scientific library directories in `LD_LIBRARY_PATH`. Set `BUILD_DIR` and optionally `EXECUTABLE` to the exact build and matching executable. Record its source revision, local edits, configure cache, module versions and archive checksum. Collect all inputs from the same build.

   ```bash
   export MODULE_ENV BUILD_DIR
   bash cross-build/capture-cuda-link.sh > "$CAPTURE_DIR/cuda-link.tar.gz"
   sha256sum "$CAPTURE_DIR/cuda-link.tar.gz"
   ```

3. **Relink on the workstation.** Transfer, verify and unpack into an empty input directory. Use an LLD with x86-64 and AArch64 ELF support. The script selects the host interpreter from the application object and preserves the ordered shared-library names of the native executable. It links the corresponding CUDA device-link object, static solver archives, target C runtime and target GCC support libraries.

   ```bash
   mkdir "$INPUTS"
   tar -xzf cuda-link.tar.gz -C "$INPUTS"
   bash cross-build/relink-cuda.sh "$INPUTS" "$OUTPUT"
   cuobjdump --all-fatbin --list-elf "$OUTPUT"
   ```

The separate cubin build checks an actual Cauchy kernel change at device-compile time. The relink uses the device payload already in the captured objects. A complete source rebuild for the AArch64 host additionally requires its host C++/CUDA cross SDK and target development dependencies.

## Login-only validation

Transfer the final executable to the intended login and activate the build's runtime profile, including its scientific and AmgX libraries. Inspect the actual NCCL path reported by `ldd`. Inspect its device images separately from those of the solver and AmgX. The same NCCL version and SONAME can contain different kernels.

```bash
export EXPECTED_SHA256               # hash printed on the workstation
# GPU login without a driver only
export DRIVER_STUB="$CUDA_HOME/lib64/stubs/libcuda.so"
bash cross-build/check-loader.sh "$EXECUTABLE"
# GPU targets
cuobjdump --all-fatbin --list-elf "$NCCL_ROOT/lib/libnccl.so"
cuobjdump --all-fatbin --list-ptx "$NCCL_ROOT/lib/libnccl.so"
```

The checker records the ELF interpreter, direct dependencies, normal loader resolution and full relocations. When the login lacks the driver it exposes the toolkit stub only to the relocation check. Keep the stub out of the job environment. A successful check establishes host ABI and symbol resolution. MPI transport, kernel execution, AmgX setup and NCCL collectives require an allocated GPU run.

The three CPU targets completed workstation source builds and login relocation checks. The three GPU targets produced target-native solver relinks and passed login relocation checks. The workstation device builds covered SM80, SM89 and SM120. These validations used no scheduler allocation.
