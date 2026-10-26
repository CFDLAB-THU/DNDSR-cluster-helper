# AOCC and GCC runtime compatibility

Inspected **2026-10-26**. AOCC 5.0 uses AMD Clang 17.0.6. Its default Linux
C++ driver selects GNU `libstdc++`, with system GCC 8 headers and link-time
files, rather than AOCC's available `libc++`. The C runtime is system glibc
2.28. Under the selected GCC-last module layer, the dynamic loader resolves
`libstdc++.so.6.0.33` and `libgcc_s` from GCC 14.2. The Open MPI C library
itself has no direct `libstdc++` dependency.

Compiler header/link-time selection and loader runtime selection differ.
AOCC's `--gcc-toolchain=<approved-gcc-prefix> -stdlib=libstdc++` explicitly
selects the reviewed GCC headers and libraries; loading GCC onto `PATH` alone
did not change AOCC's selected GCC installation in the probe. Do not assume
AOCC 5/Clang 17 can consume every newer libstdc++ header without compiling it.

AOCC application objects can be linked with compatible GCC-built libraries,
especially across C interfaces. C++ boundaries require consistent standard
library, `_GLIBCXX_USE_CXX11_ABI`, exceptions/RTTI, exposed layout and inline
definitions. Avoid cross-compiler LTO. Eigen macros/alignment and Cantera's
private Eigen types require particular care; retain the documented symbol
isolation guard. Avoid introducing competing OpenMP runtimes when libraries
already use GCC's `libgomp`.

A proposed AOCC DNDSR variant must use a separate build tree, the same
canonical dependencies after verifying ABI compatibility, and compile/link
plus C++/MPI validation before any performance comparison. The active setup
uses GCC 14.2 for both DNDSR and externals; no AOCC DNDSR variant was built.

Primary references: [Clang toolchain](https://clang.llvm.org/docs/Toolchain.html),
[GNU C++ ABI](https://gcc.gnu.org/onlinedocs/libstdc++/manual/abi.html).
