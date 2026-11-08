#!/usr/bin/env bash
set -ex
CWD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" && cd "$CWD"
NPROC=${NPROC:-$(nproc --all)}
FLAGS="-DNDEBUG -g0 -O3 -march=native -mtune=native"
INSTALL_DIR="/opt/mpi/host"
MPI_VER=${MPI_VER:-"5.0.11"} # bundles pmix v5.0.11 + prrte v3.0.14
UCX_GIT="https://github.com/openucx/ucx"
UCX_VER=${UCX_VER:-"v1.22.0"}
PMIX_GIT="https://github.com/openpmix/openpmix"
PMIX_VER=${PMIX_VER:-"v5.0.11"} # match the version bundled in ompi

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
    ./configure CFLAGS="${FLAGS}" CXXFLAGS="${FLAGS}" --prefix="${INSTALL_DIR}" --with-pmix="${INSTALL_DIR}" --with-ucx="${INSTALL_DIR}" --disable-sphinx
    make VERBOSE=1 -j "$NPROC" && make install
) 1> >(tee "$CWD/.ompi.sh.out") 2> >(tee "$CWD/.ompi.sh.err" >&2)
