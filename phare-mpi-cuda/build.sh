#!/usr/bin/env bash
set -ex
CWD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" && cd "$CWD"
CUDA_ROOT="/usr/local/cuda"
INSTALL_DIR="/opt/mpi/cuda"
MPI_VER=${MPI_VER:-"5.0.2"}
NPROC=${NPROC:-$(nproc --all)}
UCX_GIT="https://github.com/openucx/ucx"
UCX_VER=${UCX_VER:-"v1.15.0"}


[[ ! -d "ucx" ]] && git clone "${UCX_GIT}" -b "${UCX_VER}" --depth 10 --recursive --shallow-submodules
(
    cd ucx
    [[ ! -f configure ]] && ./autogen.sh
    ./configure --prefix="${INSTALL_DIR}" --with-cuda="${CUDA_ROOT}" # --with-gdrcopy=/usr
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
    ./configure --prefix="${INSTALL_DIR}" --with-cuda="${CUDA_ROOT}" --with-ucx="${INSTALL_DIR}" --with-cuda-libdir=/usr/local/cuda/lib64/stubs --disable-sphinx
    make V=1 -j "$NPROC" && make install
) 1> >(tee "$CWD/.ompi.sh.out") 2> >(tee "$CWD/.ompi.sh.err" >&2)

# test
LD_LIBRARY_PATH="${CUDA_ROOT}/lib" "${INSTALL_DIR}/bin/ompi_info" | grep "MPI ext"
