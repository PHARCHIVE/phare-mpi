#!/usr/bin/env bash
set -ex
CWD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" && cd "$CWD"
MPI="/opt/mpi/host"
FLAGS="-g3 -O3 -march=native -mtune=native -fno-omit-frame-pointer"

[[ ! -d "hdf5" ]] && git clone https://github.com/HDFGroup/hdf5 --depth 5 --recursive --shallow-submodules

(
    mkdir build && cd build
    export CC="${MPI}/bin/mpicc" CXX="${MPI}/bin/mpicxx" FC="${MPI}/bin/mpif90"
    cmake -DMPI_C_LIBRARY="${MPI}/lib/libmpi.so" \
          -G Ninja  -DHDF5_BUILD_FORTRAN=ON \
          -DCMAKE_INSTALL_PREFIX=/opt/mpi/hdf5 \
          -DHDF5_ENABLE_PARALLEL=ON \
          -DCMAKE_CXX_FLAGS="${FLAGS}" \
          -DCMAKE_C_FLAGS="${FLAGS}" \
          -DCMAKE_BUILD_TYPE="Debug" ../hdf5
    ninja && ninja install
)

