#!/usr/bin/env bash
# usage: ./build.sh [dbg|opt]   (default: dbg)
set -ex
CWD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" && cd "$CWD"

MODE=${1:-${MODE:-dbg}}
CUDA_ROOT=${CUDA_ROOT:-"/usr/local/cuda"}
NPROC=${NPROC:-$(nproc --all)}
MPI_VER=${MPI_VER:-"5.0.11"} # bundles pmix v5.0.11 + prrte v3.0.14
UCX_GIT="https://github.com/openucx/ucx"
UCX_VER=${UCX_VER:-"v1.22.0"}
PMIX_GIT="https://github.com/openpmix/openpmix"
PMIX_VER=${PMIX_VER:-"v5.0.11"} # match the version bundled in ompi

case "${MODE}" in
dbg) FLAGS="-g3 -O3 -march=native -mtune=native -fno-omit-frame-pointer" ;;
opt) FLAGS="-DNDEBUG -g0 -O3 -march=native -mtune=native" ;;
*)
    echo "unknown mode '${MODE}', expected dbg or opt" >&2
    exit 1
    ;;
esac

INSTALL_DIR=${INSTALL_DIR:-"/opt/mpi/cuda-${MODE}"}
BUILD_DIR="${CWD}/build-${MODE}"
LOG="${CWD}/.${MODE}"

# sources are shared between modes, builds are out of tree (VPATH)
[[ ! -d "pmix" ]] && git clone "${PMIX_GIT}" -b "${PMIX_VER}" --depth 10 --recursive --shallow-submodules pmix
[[ ! -d "ucx" ]] && git clone "${UCX_GIT}" -b "${UCX_VER}" --depth 10 --recursive --shallow-submodules ucx

get_ompi() (
    [ -n "${MPI_VER}" ] || (echo "FAIL" && exit 1)
    # use the release tarball (make dist), not a github tag archive: it ships the generated
    # configure, the bundled pmix/prrte submodules and prebuilt docs (hence --disable-sphinx)
    [ ! -f "openmpi-${MPI_VER}.tar.bz2" ] && wget "https://download.open-mpi.org/release/open-mpi/v5.0/openmpi-${MPI_VER}.tar.bz2"
    tar xf "openmpi-${MPI_VER}.tar.bz2"
    mv "openmpi-${MPI_VER}" ompi
)
[[ ! -d "ompi" ]] && get_ompi

[[ -f pmix/configure ]] || (cd pmix && ./autogen.pl)
[[ -f ucx/configure ]] || (cd ucx && ./autogen.sh)
[[ -f ompi/configure ]] || (cd ompi && ./autogen.pl)

rm -rf "${BUILD_DIR}" && mkdir -p "${BUILD_DIR}"/{pmix,ucx,ompi}

(
    cd "${BUILD_DIR}/pmix"
    "${CWD}/pmix/configure" CFLAGS="${FLAGS}" CXXFLAGS="${FLAGS}" --prefix="${INSTALL_DIR}"
    make VERBOSE=1 -j "$NPROC" && make install
) 1> >(tee "${LOG}.pmix.sh.out") 2> >(tee "${LOG}.pmix.sh.err" >&2)

(
    cd "${BUILD_DIR}/ucx"
    "${CWD}/ucx/configure" CFLAGS="${FLAGS}" CXXFLAGS="${FLAGS}" --prefix="${INSTALL_DIR}" \
        --with-cuda="${CUDA_ROOT}" --without-knem # --with-gdrcopy=/usr
    make VERBOSE=1 -j "$NPROC" && make install
) 1> >(tee "${LOG}.ucx.sh.out") 2> >(tee "${LOG}.ucx.sh.err" >&2)

(
    cd "${BUILD_DIR}/ompi"
    "${CWD}/ompi/configure" CFLAGS="${FLAGS}" CXXFLAGS="${FLAGS}" --prefix="${INSTALL_DIR}" \
        --with-pmix="${INSTALL_DIR}" --with-ucx="${INSTALL_DIR}" \
        --with-cuda="${CUDA_ROOT}" --with-cuda-libdir="${CUDA_ROOT}/lib64/stubs" --disable-sphinx
    make V=1 -j "$NPROC" && make install
) 1> >(tee "${LOG}.ompi.sh.out") 2> >(tee "${LOG}.ompi.sh.err" >&2)

# test
"${INSTALL_DIR}/bin/ompi_info" --parsable --all | grep mpi_built_with_cuda_support:value:true
