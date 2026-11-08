#!/usr/bin/env bash
# usage: ./build.sh [dbg|opt]   env: see ../build_mpi.sh (INSTALL_DIR, SRC_DIR, BUILD_ROOT, ...)
set -e
CWD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" && cd "$CWD"
exec ../build_mpi.sh cuda "$@"
