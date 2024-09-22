#!/usr/bin/env bash
set -ex
CWD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" && cd "$CWD"

[[ ! -d "hdf5" ]] && git clone https://github.com/HDFGroup/hdf5 --depth 5 --recursive --shallow-submodules

(
    mkdir build && cd build
    export CC=/opt/mpi/rocm/bin/mpicc CXX=/opt/mpi/rocm/bin/mpicxx
    cmake -DMPI_C_LIBRARY=/opt/mpi/rocm/lib/libmpi.so \
          -G Ninja  -DHDF5_BUILD_FORTRAN=ON \
          -DCMAKE_INSTALL_PREFIX=/opt/mpi/rocm_hdf5 \
          -DHDF5_ENABLE_PARALLEL=ON ../hdf5
)

