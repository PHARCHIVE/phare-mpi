#!/usr/bin/env bash
set -ex
CWD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" && cd "$CWD"

ROCM_ROOT="/opt/rocm"
NPROC=${NPROC:-$(nproc --all)}
MPI_VER="5.0.0rc9"
MPI_BIN="${CWD}/build/ompi"

UCX_GIT="https://github.com/openucx/ucx"
UCX_VER="v1.15.0"
UCX_BIN="${CWD}/build/ucx"

[[ ! -d "ucx" ]] && git clone "${UCX_GIT}" -b "${UCX_VER}" --depth 10 --recursive --shallow-submodules
(
    cd ucx
    [[ ! -f configure ]] && ./autogen.sh
    ./configure --prefix="${UCX_BIN}" \
        --with-rocm="${ROCM_ROOT}" --without-knem
    make -j "$NPROC" && make install
) 1> >(tee "$CWD/.ucx.sh.out") 2> >(tee "$CWD/.ucx.sh.err" >&2)

get_ompi() (
    [ -n "${MPI_VER}" ] || (echo "FAIL" && exit 1)
    # tar ball version is different to github repo tag for unknown reasons
    [ ! -f "openmpi-${MPI_VER}.tar.bz2" ] && wget "https://download.open-mpi.org/release/open-mpi/v5.0/openmpi-${MPI_VER}.tar.bz2"
    tar xf "openmpi-${MPI_VER}.tar.bz2"
    mv "openmpi-${MPI_VER}" ompi
)

[[ ! -d "ompi" ]] && get_ompi
(
    cd ompi
    [[ ! -f configure ]] && ./autogen.pl
    ./configure --prefix="${MPI_BIN}" \
        --with-rocm="${ROCM_ROOT}" \
        --with-ucx="${UCX_BIN}"
    make -j "$NPROC" && make install
) 1> >(tee "$CWD/.ompi.sh.out") 2> >(tee "$CWD/.ompi.sh.err" >&2)

# test
LD_LIBRARY_PATH="${ROCM_ROOT}/lib" "${MPI_BIN}/bin/ompi_info" | grep "MPI ext"
