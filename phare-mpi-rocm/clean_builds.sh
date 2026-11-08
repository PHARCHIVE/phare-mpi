#!/usr/bin/env bash
set -ex
CWD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" && cd "$CWD"
BUILD_ROOT=${BUILD_ROOT:-"$CWD"}
rm -rf "${BUILD_ROOT}"/build-rocm-* "${BUILD_ROOT}"/.rocm-*.sh.*
