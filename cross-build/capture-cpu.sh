#!/usr/bin/env bash
# Run under the target CPU profile. Stream a private sysroot as a gzip tarball.
set -eo pipefail
if [[ -n ${MODULE_ENV:-} ]]; then source "$MODULE_ENV" >&2; fi
set -u
: "${EXTERNALS_PREFIX:?Set the populated target cfd_externals install prefix}"
ext=$(realpath -e "$EXTERNALS_PREFIX")
gcc_root=$(dirname "$(dirname "$(command -v gcc)")")
mpi_root=$(dirname "$(dirname "$(command -v mpicc)")")
gcc_lib=$(realpath -ms "$(dirname "$(gcc -print-libgcc-file-name)")")
[[ $(uname -m) == x86_64 && -f "$ext/lib/libhdf5.so" && -f "$mpi_root/include/mpi.h" ]]
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
# Keep site paths relative to the sysroot. Record the selections for the wrapper.
printf 'GCC_ROOT=%q\nGCC_LIB=%q\nMPI_ROOT=%q\nEXT_ROOT=%q\n' \
    "$gcc_root" "$gcc_lib" "$mpi_root" "$ext" > "$tmp/target.env"
printf 'GCC_VERSION=%q\nGCC_TRIPLE=%q\n' "$(gcc -dumpfullversion)" "$(gcc -dumpmachine)" >> "$tmp/target.env"
cd /
rpm -ql glibc-headers.x86_64 glibc-devel.x86_64 kernel-headers.x86_64 > "$tmp/rpm"
{
    while IFS= read -r p; do
        case "$p" in /usr/include/*|/usr/lib64/*) if [[ -f $p ]]; then echo "$p"; fi;; esac
    done < "$tmp/rpm"
    shopt -s nullglob
    for p in "$gcc_root"/bin/{gcc,g++} "$(gcc -print-prog-name=cc1)" "$(g++ -print-prog-name=cc1plus)" "$(gcc -print-prog-name=collect2)"; do
        test -f "$p"
        echo "$p"
        ldd "$p" | awk '$1 ~ /^lib(mpfr|gmp|mpc|isl|zstd)/ && $2=="=>" {print $3}'
    done
    for name in include include-fixed libgomp.spec libstdc++fs.a liblto_plugin.so libatomic.so libbacktrace.a libgomp.so libquadmath.so.0; do
        p=$(gcc -print-file-name="$name")
        if [[ $p == /* && -e $p ]]; then echo "$p"; fi
    done
    printf '%s\n' "$gcc_root/include/c++" "$gcc_lib"/{crt*.o,libgcc*.a} "$gcc_root"/lib64/{libstdc++.so*,libgcc_s.so*,libgomp.so*} \
        "$mpi_root/include" "$mpi_root"/lib/libmpi.so* "$ext/include" "$ext/lib"
    for p in /lib64/{ld-linux-x86-64.so.2,libc.so.6,libm.so.6,libpthread.so.0,libdl.so.2,librt.so.1,libmvec.so*,libz.so*,libgfortran.so*,libquadmath.so*}; do
        if [[ -f $p ]]; then echo "$p"; fi
    done
} | tr '\n' '\0' | xargs -0 -r realpath -ms -- | sed 's|^/||' | sort -u > "$tmp/paths"
tar --dereference -czf - -T "$tmp/paths" -C "$tmp" target.env
