#!/usr/bin/env bash
set -ex
CWD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" && cd "$CWD"

ROCM_ROOT="/opt/rocm"
INSTALL_DIR="/opt/mpi/rocm"
MPI_VER=${MPI_VER:-"5.0.11"} # bundles pmix v5.0.11 + prrte v3.0.14
NPROC=${NPROC:-$(nproc --all)}
UCX_GIT="https://github.com/openucx/ucx"
UCX_VER=${UCX_VER:-"v1.22.0"}

[[ ! -d "ucx" ]] && git clone "${UCX_GIT}" -b "${UCX_VER}" --depth 10 --recursive --shallow-submodules
(
    cd ucx
    [[ ! -f configure ]] && ./autogen.sh
    ./configure --prefix="${INSTALL_DIR}" --with-rocm="${ROCM_ROOT}" --without-knem
    make -j "$NPROC" && make install
) 1> >(tee "$CWD/.ucx.sh.out") 2> >(tee "$CWD/.ucx.sh.err" >&2)

get_ompi() (
    [ -n "${MPI_VER}" ] || (echo "FAIL" && exit 1)
    # use the release tarball (make dist), not a github tag archive: it ships the generated
    # configure, the bundled pmix/prrte submodules and prebuilt docs (hence --disable-sphinx)
    [ ! -f "openmpi-${MPI_VER}.tar.bz2" ] && wget "https://download.open-mpi.org/release/open-mpi/v5.0/openmpi-${MPI_VER}.tar.bz2"
    tar xf "openmpi-${MPI_VER}.tar.bz2"
    mv "openmpi-${MPI_VER}" ompi
)

[[ ! -d "ompi" ]] && get_ompi
(
    cd ompi
    [[ ! -f configure ]] && ./autogen.pl
    ./configure --prefix="${INSTALL_DIR}" --with-rocm="${ROCM_ROOT}" --with-ucx="${INSTALL_DIR}" --disable-sphinx
    make -j "$NPROC" && make install
) 1> >(tee "$CWD/.ompi.sh.out") 2> >(tee "$CWD/.ompi.sh.err" >&2)

# test
LD_LIBRARY_PATH="${ROCM_ROOT}/lib" "${INSTALL_DIR}/bin/ompi_info" | grep "MPI ext"
