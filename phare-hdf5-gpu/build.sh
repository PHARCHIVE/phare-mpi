#!/usr/bin/env bash
set -ex
CWD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" && cd "$CWD"

INSTALL_DIR=${INSTALL_DIR:-"/opt/mpi/rocm_hdf5"}
CC=${CC:-"/opt/mpi/rocm/bin/mpicc"}
CXX=${CXX:-"/opt/mpi/rocm/bin/mpicxx"}
FC=${FC:-"/opt/rocm-6.2.1/bin/amdflang"}
MPI_C_LIBRARY=${MPI_C_LIBRARY:="-DMPI_C_LIBRARY=/opt/mpi/rocm/lib/libmpi.so"}
CMAKE_CONFIG=${CMAKE_CONFIG:=""}

CMAKE_CONFIG="${CMAKE_CONFIG} ${MPI_C_LIBRARY}"

[[ ! -d "hdf5" ]] && git clone https://github.com/HDFGroup/hdf5 --depth 5 --recursive --shallow-submodules

(
    rm -rf build && mkdir build && cd build
    export CC CXX FC
    cmake -G Ninja  -DHDF5_BUILD_FORTRAN=ON \
          -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
          -DHDF5_ENABLE_PARALLEL=ON ../hdf5
    ninja && ninja install
)
