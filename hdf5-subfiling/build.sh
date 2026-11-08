#!/usr/bin/env bash
# usage: ./build.sh [dbg|opt] [host|cuda]   (default: dbg host)
set -ex
CWD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" && cd "$CWD"

MODE=${1:-${MODE:-dbg}}
MPI_FLAVOR=${2:-${MPI_FLAVOR:-host}}
HDF5_GIT="https://github.com/HDFGroup/hdf5"
HDF5_VER=${HDF5_VER:-""} # git tag/branch, empty for default branch

case "${MODE}" in
dbg)
    FLAGS="-g3 -O3 -march=native -mtune=native -fno-omit-frame-pointer"
    BUILD_TYPE="Debug"
    ;;
opt)
    FLAGS="-DNDEBUG -g0 -O3 -march=native -mtune=native"
    BUILD_TYPE="Release"
    ;;
*)
    echo "unknown mode '${MODE}', expected dbg or opt" >&2
    exit 1
    ;;
esac

case "${MPI_FLAVOR}" in
host) MPI=${MPI:-"/opt/mpi/host"} ;;
cuda) MPI=${MPI:-"/opt/mpi/cuda-${MODE}"} ;;
*)
    echo "unknown mpi flavor '${MPI_FLAVOR}', expected host or cuda" >&2
    exit 1
    ;;
esac

TAG="${MPI_FLAVOR}-${MODE}"
INSTALL_DIR=${INSTALL_DIR:-"/opt/mpi/hdf5-subfiling-${TAG}"}
BUILD_DIR="${CWD}/build-${TAG}"

if [[ ! -d "hdf5" ]]; then
    git clone "${HDF5_GIT}" ${HDF5_VER:+-b "${HDF5_VER}"} --depth 5 --recursive --shallow-submodules hdf5
fi

(
    rm -rf "${BUILD_DIR}" && mkdir "${BUILD_DIR}" && cd "${BUILD_DIR}"
    export CC="${MPI}/bin/mpicc" CXX="${MPI}/bin/mpicxx" FC="${MPI}/bin/mpif90"
    cmake -G Ninja \
        -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
        -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
        -DCMAKE_C_FLAGS="${FLAGS}" \
        -DCMAKE_CXX_FLAGS="${FLAGS}" \
        -DCMAKE_Fortran_FLAGS="${FLAGS}" \
        -DMPI_C_LIBRARY="${MPI}/lib/libmpi.so" \
        -DMPIEXEC_EXECUTABLE="${MPI}/bin/mpiexec" \
        -DHDF5_ENABLE_PARALLEL=ON \
        -DHDF5_ENABLE_SUBFILING_VFD=ON \
        -DHDF5_BUILD_FORTRAN=ON \
        "${CWD}/hdf5"
    ninja && ninja install
) 1> >(tee "$CWD/.hdf5-${TAG}.sh.out") 2> >(tee "$CWD/.hdf5-${TAG}.sh.err" >&2)
