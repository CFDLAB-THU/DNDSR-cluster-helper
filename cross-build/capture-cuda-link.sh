#!/usr/bin/env bash
# Capture the inputs of a trusted native Cauchy CUDA build. Archive on stdout.
set -eo pipefail
if [[ -n ${MODULE_ENV:-} ]]; then source "$MODULE_ENV" >&2; fi
set -u
b=$(realpath -e "${BUILD_DIR:?}")
exe=$(realpath -e "${EXECUTABLE:-$b/app/cauchy.exe}")
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
cd "$tmp"
mkdir lib obj
readelf -dW "$exe" > elf.txt
sha256sum "$exe" > native.sha256
ldd "$exe" > ldd.txt
sed -n 's/.*Shared library: \[\([^]]*\)\]/\1/p' elf.txt > needed.txt
test -s needed.txt
for f in "$b"/CMakeFiles/cauchy_solver.dir/{app/Cauchy/cauchy.cpp.o,cmake_device_link.o} \
    "$b"/src/{Cauchy/libcauchy,CFV/libcfv,Geom/libgeom,Physics/libphysics,DNDS/libdnds}.a "$b/fmt/libfmt.a" \
    "$CUDA_HOME/lib64/libcudadevrt.a"; do
    test -f "$f"
    ln -s "$f" obj/
done
for n in crt1.o crti.o crtbegin.o crtend.o crtn.o libgcc.a libstdc++fs.a libc_nonshared.a; do
    f=$(gcc -print-file-name="$n")
    test -f "$f"
    ln -s "$(realpath "$f")" "obj/$n"
done
while IFS= read -r n; do
    so=$(awk -v n="$n" '$1==n && $2=="=>" && $3!="not" {print $3;exit} $1 ~ /^\// && $1 ~ ("/" n "$") {print $1;exit}' ldd.txt)
    case "$n" in
        libnccl.so.2) so="$NCCL_ROOT/lib/libnccl.so.2";;
        libcuda.so.1) so="$CUDA_HOME/lib64/stubs/libcuda.so";;
        libcublas*|libcusolver*|libcusparse*|libnvJitLink*)
            stub="$CUDA_HOME/lib64/stubs/${n%%.so*}.so"
            if [[ -f $stub ]]; then so=$stub; fi;;
    esac
    [[ -f $so ]] || { echo "Missing target link input: $n" >&2; exit 1; }
    ln -s "$so" "lib/$n"
done < needed.txt
tar -hczf - obj lib native.sha256 needed.txt elf.txt ldd.txt
