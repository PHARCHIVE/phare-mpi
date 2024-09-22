#!/usr/bin/env bash
set -ex
CWD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" && cd "$CWD"
NPROC=${NPROC:-$(nproc --all)}
FLAGS="-g3 -O3 -march=native -mtune=native -fno-omit-frame-pointer"
INSTALL_DIR="/opt/mpi/host"
MPI_VER=${MPI_VER:-"5.0.5"} # "5.0.0rc9" for older libpmix
UCX_GIT="https://github.com/openucx/ucx"
UCX_VER=${UCX_VER:-"v1.17.0"}
PMIX_GIT="https://github.com/openpmix/openpmix"
PMIX_VER="v5.0.3"

[[ ! -d "pmix" ]] && git clone "${PMIX_GIT}" -b "${PMIX_VER}" --depth 10 --recursive --shallow-submodules pmix
(
    cd pmix
    [[ ! -f configure ]] && ./autogen.pl
    ./configure CFLAGS="${FLAGS}" CXXFLAGS="${FLAGS}" --prefix="${INSTALL_DIR}"
    make VERBOSE=1 -j "$NPROC" && make install
) 1> >(tee "$CWD/.pmix.sh.out") 2> >(tee "$CWD/.pmix.sh.err" >&2)

[[ ! -d "ucx" ]] && git clone "${UCX_GIT}" -b "${UCX_VER}" --depth 10 --recursive --shallow-submodules
(
    cd ucx
    [[ ! -f configure ]] && ./autogen.sh
    ./configure CFLAGS="${FLAGS}" CXXFLAGS="${FLAGS}" --prefix="${INSTALL_DIR}" --without-knem
    make VERBOSE=1 -j "$NPROC" && make install
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
    ./configure CFLAGS="${FLAGS}" CXXFLAGS="${FLAGS}" --prefix="${INSTALL_DIR}" --with-pmix="${INSTALL_DIR}" --with-ucx="${INSTALL_DIR}" --disable-sphinx
    make VERBOSE=1 -j "$NPROC" && make install
) 1> >(tee "$CWD/.ompi.sh.out") 2> >(tee "$CWD/.ompi.sh.err" >&2)

# test
# "${INSTALL_DIR}/bin/ompi_info" | grep "MPI ext"
