#!/usr/bin/env bash
set -ex

CWD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" && cd "$CWD"
rm -rf build-dbg build-opt ompi ucx pmix
