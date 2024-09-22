#!/usr/bin/env bash
set -ex
CWD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" && cd "$CWD"
shellcheck -x ./*.sh
shfmt -i 4 -w ./*.sh
