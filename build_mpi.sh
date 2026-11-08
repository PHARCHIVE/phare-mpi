#!/usr/bin/env bash
# usage: ./build_mpi.sh <host|cuda|rocm> [dbg|opt]   (default mode: dbg)
#
# builds pmix -> ucx -> openmpi into one prefix
#
# env:
#   INSTALL_DIR  install prefix              (default /opt/mpi/<flavor>-<mode>)
#   SRC_DIR      downloads + source trees    (default $PWD), shareable between flavors/modes
#   BUILD_ROOT   build trees + logs          (default $PWD), shareable between flavors/modes
#   NPROC, MPI_VER, UCX_VER, PMIX_VER, CUDA_ROOT, ROCM_ROOT
set -ex

FLAVOR=${1:-${FLAVOR:-}}
MODE=${2:-${MODE:-dbg}}
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

UCX_EXTRA=()
OMPI_EXTRA=()
case "${FLAVOR}" in
host) ;;
cuda)
    CUDA_ROOT=${CUDA_ROOT:-"/usr/local/cuda"}
    UCX_EXTRA=(--with-cuda="${CUDA_ROOT}") # --with-gdrcopy=/usr
    OMPI_EXTRA=(--with-cuda="${CUDA_ROOT}" --with-cuda-libdir="${CUDA_ROOT}/lib64/stubs")
    ;;
rocm)
    ROCM_ROOT=${ROCM_ROOT:-"/opt/rocm"}
    UCX_EXTRA=(--with-rocm="${ROCM_ROOT}")
    OMPI_EXTRA=(--with-rocm="${ROCM_ROOT}")
    ;;
*)
    echo "unknown flavor '${FLAVOR}', expected host, cuda or rocm" >&2
    exit 1
    ;;
esac

TAG="${FLAVOR}-${MODE}"
INSTALL_DIR=${INSTALL_DIR:-"/opt/mpi/${TAG}"}
SRC_DIR=$(mkdir -p "${SRC_DIR:-$PWD}" && cd "${SRC_DIR:-$PWD}" && pwd)
BUILD_ROOT=$(mkdir -p "${BUILD_ROOT:-$PWD}" && cd "${BUILD_ROOT:-$PWD}" && pwd)
BUILD_DIR="${BUILD_ROOT}/build-${TAG}"
LOG="${BUILD_ROOT}/.${TAG}"

# sources are versioned so they can be shared, builds are always out of tree (VPATH)
PMIX_SRC="${SRC_DIR}/pmix-${PMIX_VER}"
UCX_SRC="${SRC_DIR}/ucx-${UCX_VER}"
OMPI_SRC="${SRC_DIR}/openmpi-${MPI_VER}"

[[ -d "${PMIX_SRC}" ]] || git clone "${PMIX_GIT}" -b "${PMIX_VER}" --depth 10 --recursive --shallow-submodules "${PMIX_SRC}"
[[ -d "${UCX_SRC}" ]] || git clone "${UCX_GIT}" -b "${UCX_VER}" --depth 10 --recursive --shallow-submodules "${UCX_SRC}"

# use the release tarball (make dist), not a github tag archive: it ships the generated
# configure, the bundled pmix/prrte submodules and prebuilt docs (hence --disable-sphinx)
if [[ ! -d "${OMPI_SRC}" ]]; then
    TARBALL="${SRC_DIR}/openmpi-${MPI_VER}.tar.bz2"
    [[ -f "${TARBALL}" ]] || wget -O "${TARBALL}" "https://download.open-mpi.org/release/open-mpi/v${MPI_VER%.*}/openmpi-${MPI_VER}.tar.bz2"
    tar xf "${TARBALL}" -C "${SRC_DIR}"
fi

[[ -f "${PMIX_SRC}/configure" ]] || (cd "${PMIX_SRC}" && ./autogen.pl)
[[ -f "${UCX_SRC}/configure" ]] || (cd "${UCX_SRC}" && ./autogen.sh)

rm -rf "${BUILD_DIR}" && mkdir -p "${BUILD_DIR}"/{pmix,ucx,ompi}

(
    cd "${BUILD_DIR}/pmix"
    "${PMIX_SRC}/configure" CFLAGS="${FLAGS}" CXXFLAGS="${FLAGS}" --prefix="${INSTALL_DIR}"
    make VERBOSE=1 -j "$NPROC" && make install
) 1> >(tee "${LOG}.pmix.sh.out") 2> >(tee "${LOG}.pmix.sh.err" >&2)

# ucx hardcodes -Werror; gcc 13 (e.g. ubuntu 24.04) emits a false positive maybe-uninitialized
# in ucs/arch/bitops.h at -O3, our flags come after ucx's own so this downgrades it to a warning
UCX_FLAGS="${FLAGS} -Wno-error=maybe-uninitialized"
(
    cd "${BUILD_DIR}/ucx"
    "${UCX_SRC}/configure" CFLAGS="${UCX_FLAGS}" CXXFLAGS="${UCX_FLAGS}" --prefix="${INSTALL_DIR}" \
        --without-knem "${UCX_EXTRA[@]}"
    make VERBOSE=1 -j "$NPROC" && make install
) 1> >(tee "${LOG}.ucx.sh.out") 2> >(tee "${LOG}.ucx.sh.err" >&2)

(
    cd "${BUILD_DIR}/ompi"
    "${OMPI_SRC}/configure" CFLAGS="${FLAGS}" CXXFLAGS="${FLAGS}" --prefix="${INSTALL_DIR}" \
        --with-pmix="${INSTALL_DIR}" --with-ucx="${INSTALL_DIR}" --disable-sphinx "${OMPI_EXTRA[@]}"
    make V=1 -j "$NPROC" && make install
) 1> >(tee "${LOG}.ompi.sh.out") 2> >(tee "${LOG}.ompi.sh.err" >&2)

# test
case "${FLAVOR}" in
cuda) "${INSTALL_DIR}/bin/ompi_info" --parsable --all | grep mpi_built_with_cuda_support:value:true ;;
rocm) "${INSTALL_DIR}/bin/ompi_info" | grep -i "MCA accelerator: rocm" ;;
*) "${INSTALL_DIR}/bin/ompi_info" | grep "Open MPI:" ;;
esac
