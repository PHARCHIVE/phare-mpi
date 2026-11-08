#!/usr/bin/env bash
# usage: ./build_stack.sh [cuda|rocm|host] [opt|dbg]   (default: cuda opt)
#
# wraps the existing scripts: phare-mpi-<flavor|mode>/build.sh (pmix -> ucx -> openmpi),
# then hdf5-subfiling/build.sh against that mpi,
# then checks neither links mpi-stack libraries from anywhere else
#
# env:
#   WORK_DIR          parent of src/ and build/           (default: <repo>/work)
#   SRC_DIR           downloads + source trees            (default: $WORK_DIR/src)
#   BUILD_ROOT        build trees + logs                  (default: $WORK_DIR/build)
#   MPI_INSTALL_DIR   mpi prefix                          (default: /opt/mpi/<flavor>-<mode>)
#   HDF5_INSTALL_DIR  hdf5 prefix                         (default: /opt/mpi/hdf5-subfiling-<flavor>-<mode>)
#   NPROC             parallel build jobs, all steps      (default: all cores)
#   plus anything build_mpi.sh / hdf5-subfiling/build.sh read:
#   MPI_VER, UCX_VER, PMIX_VER, HDF5_VER, CUDA_ROOT, ROCM_ROOT
#
# e.g. WORK_DIR=/bk/mpi MPI_INSTALL_DIR=/opt/mpi/cuda HDF5_INSTALL_DIR=/opt/mpi/hdf5-cuda ./build_stack.sh
set -ex
CWD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FLAVOR=${1:-cuda}
MODE=${2:-opt}
TAG="${FLAVOR}-${MODE}"

if [[ "${MODE}" != "opt" && "${MODE}" != "dbg" ]]; then
    echo "unknown mode '${MODE}', expected opt or dbg" >&2
    exit 1
fi

case "${FLAVOR}" in
cuda | rocm) MPI_SCRIPT=("${CWD}/phare-mpi-${FLAVOR}/build.sh" "${MODE}") ;;
host) MPI_SCRIPT=("${CWD}/phare-mpi-${MODE}/build.sh") ;; # phare-mpi-dbg / phare-mpi-opt
*)
    echo "unknown flavor '${FLAVOR}', expected cuda, rocm or host" >&2
    exit 1
    ;;
esac

WORK_DIR=${WORK_DIR:-"${CWD}/work"}
export SRC_DIR=${SRC_DIR:-"${WORK_DIR}/src"}
export BUILD_ROOT=${BUILD_ROOT:-"${WORK_DIR}/build"}
MPI_INSTALL_DIR=${MPI_INSTALL_DIR:-"/opt/mpi/${TAG}"}
HDF5_INSTALL_DIR=${HDF5_INSTALL_DIR:-"/opt/mpi/hdf5-subfiling-${TAG}"}
unset INSTALL_DIR MPI # only the explicit names above apply

INSTALL_DIR="${MPI_INSTALL_DIR}" "${MPI_SCRIPT[@]}"
"${CWD}/.github/scripts/check_linkage.sh" "${MPI_INSTALL_DIR}"

MPI="${MPI_INSTALL_DIR}" INSTALL_DIR="${HDF5_INSTALL_DIR}" "${CWD}/hdf5-subfiling/build.sh" "${MODE}" "${FLAVOR}"
"${CWD}/.github/scripts/check_linkage.sh" "${HDF5_INSTALL_DIR}" "${MPI_INSTALL_DIR}"

set +x
echo
echo "mpi : ${MPI_INSTALL_DIR}"
echo "hdf5: ${HDF5_INSTALL_DIR}"
echo "logs: ${BUILD_ROOT}/.${TAG}.*.sh.{out,err} ${BUILD_ROOT}/.hdf5-${TAG}.sh.{out,err}"
echo "use : export PATH=${MPI_INSTALL_DIR}/bin:\$PATH HDF5_ROOT=${HDF5_INSTALL_DIR}"
