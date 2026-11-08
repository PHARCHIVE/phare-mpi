#!/usr/bin/env bash
# also removes downloaded sources, which may be shared with other flavors if SRC_DIR is
set -ex
CWD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" && cd "$CWD"
SRC_DIR=${SRC_DIR:-"$CWD"}
./clean_builds.sh
rm -rf "${SRC_DIR}"/pmix-* "${SRC_DIR}"/ucx-* "${SRC_DIR}"/openmpi-*
