#!/usr/bin/env bash
# CMake invokes symlinks named cc and cxx pointing here.
set -eu
root=${TARGET_SYSROOT:?}
source "$root/target.env"
bin="$root$GCC_ROOT/bin"
args=(--sysroot="$root" "-B$root$GCC_LIB/" "-B$root/usr/lib64/" -fno-use-linker-plugin -march=x86-64 -mtune=generic
    "-L$root$GCC_ROOT/lib64" "-L$root/usr/lib64" "-L$root/lib64" -Wl,--allow-shlib-undefined)
case ${0##*/} in
    cc) compiler="$bin/gcc";;
    cxx) compiler="$bin/g++"
        inc="$root$GCC_ROOT/include/c++/$GCC_VERSION"
        args+=(-nostdinc++ -isystem "$inc" -isystem "$inc/$GCC_TRIPLE" -isystem "$inc/backward");;
    *) echo 'Invoke through the cc or cxx symlink created by configure-cpu.sh' >&2; exit 2;;
esac
# Only dependencies of the copied compiler run on the workstation.
export LD_LIBRARY_PATH="${HOST_COMPILER_LIBS:?}"
exec "$compiler" "${args[@]}" "$@"
