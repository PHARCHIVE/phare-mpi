#!/usr/bin/env bash
# usage: ./check.sh [dbg|opt]   (default: dbg)
set -ex

MODE=${1:-${MODE:-dbg}}
INSTALL_DIR=${INSTALL_DIR:-"/opt/mpi/cuda-${MODE}"}
"${INSTALL_DIR}/bin/ompi_info" --parsable --all | grep mpi_built_with_cuda_support:value
