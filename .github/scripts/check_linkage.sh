#!/usr/bin/env bash
# usage: check_linkage.sh PREFIX [ALLOWED_PREFIX...]
#  fails if any ELF under PREFIX resolves an MPI-stack library (mpi/pmix/ucx/prrte/hdf5)
#  from outside the allowed prefixes (PREFIX is always allowed), or can't resolve it at all
set -eu

PREFIX="$1"
shift
ALLOWED=("$PREFIX" "$@")
STACK_LIBS='lib(mpi|mpi_mpifh|mpi_usempi|open-pal|open-rte|prrte|pmix|ucp|ucs|uct|ucm|hdf5)[^ ]*\.so'

fail=0
while IFS= read -r -d '' f; do
    file -b "$f" | grep -q ELF || continue
    while read -r line; do
        lib=$(awk '{print $1}' <<<"$line")
        path=$(awk '{print $3}' <<<"$line")
        if [[ "$path" == "not" || -z "$path" ]]; then
            echo "UNRESOLVED: $f -> $lib"
            fail=1
            continue
        fi
        ok=0
        for a in "${ALLOWED[@]}"; do [[ "$path" == "$a"/* ]] && ok=1; done
        if [[ $ok == 0 ]]; then
            echo "FOREIGN: $f -> $lib => $path"
            fail=1
        fi
    done < <(ldd "$f" 2>/dev/null | grep -E "$STACK_LIBS" || true)
done < <(find "$PREFIX/bin" "$PREFIX/lib" "$PREFIX/lib64" -type f \( -perm -u+x -o -name '*.so*' \) -print0 2>/dev/null)

[[ $fail == 0 ]] && echo "linkage OK: ${ALLOWED[*]}"
exit $fail
