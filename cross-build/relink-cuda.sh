#!/usr/bin/env bash
# Relink target-native objects on the workstation without executing target code.
set -euo pipefail
inputs=$(realpath -e "${1:?Specify the captured linker-input directory}")
output=$(realpath -m "${2:?Specify the output executable}")
cd "$inputs"
case $(LC_ALL=C readelf -h obj/cauchy.cpp.o | awk -F: '/Machine:/{print $2}') in
    *AArch64*) emulation=aarch64linux; interpreter=/lib/ld-linux-aarch64.so.1;;
    *X86-64*) emulation=elf_x86_64; interpreter=/lib64/ld-linux-x86-64.so.2;;
    *) echo 'Unsupported target host architecture' >&2; exit 1;;
esac
libs=()
while IFS= read -r name; do
    test -f "lib/$name"
    libs+=("-l:$name")
done < needed.txt
"${LLD:-ld.lld}" -m "$emulation" --dynamic-linker "$interpreter" --hash-style=both --build-id=sha1 \
    --eh-frame-hdr --export-dynamic -z noexecstack --allow-shlib-undefined -o "$output" -Llib \
    obj/{crt1.o,crti.o,crtbegin.o,cauchy.cpp.o,cmake_device_link.o} --start-group \
    obj/lib{cauchy,cfv,geom,physics,dnds,fmt,stdc++fs,cudadevrt,gcc}.a --no-as-needed "${libs[@]}" \
    "${LIBC_NONSHARED:-obj/libc_nonshared.a}" --end-group obj/crtend.o obj/crtn.o
diff -u needed.txt <(readelf -dW "$output" | sed -n 's/.*Shared library: \[\([^]]*\)\]/\1/p')
sha256sum "$output"
