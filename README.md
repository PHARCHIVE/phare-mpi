# phare-mpi

Build scripts for an MPI stack (PMIx → UCX → Open MPI) with optional CUDA or ROCm support, plus
parallel HDF5 with the subfiling VFD built against it. Every flavor has a debug (`dbg`) and an
optimized (`opt`) build.

## Quick start

```bash
# optimized CUDA MPI + HDF5, sources/builds under /bk/mpi, 4 build jobs
NPROC=4 WORK_DIR=/bk/mpi \
MPI_INSTALL_DIR=/opt/mpi/cuda HDF5_INSTALL_DIR=/opt/mpi/hdf5-cuda \
./build_stack.sh cuda opt
```

`build_stack.sh [cuda|rocm|host] [opt|dbg]` (default `cuda opt`) builds MPI, then HDF5 against it,
and runs the linkage check on both. The install prefixes must be writable by you
(e.g. `sudo chown $USER /opt/mpi`).

Afterwards:

```bash
export PATH=/opt/mpi/cuda/bin:$PATH HDF5_ROOT=/opt/mpi/hdf5-cuda
```

## Layout

| Path | What |
|---|---|
| `build_stack.sh` | MPI + HDF5 for one flavor/mode, with linkage checks. Wraps the scripts below. |
| `build_mpi.sh` | `<host\|cuda\|rocm> [dbg\|opt]` – the actual PMIx/UCX/Open MPI build. |
| `phare-mpi-cuda/build.sh`, `phare-mpi-rocm/build.sh` | `[dbg\|opt]` wrappers for `build_mpi.sh`. |
| `phare-mpi-dbg/build.sh`, `phare-mpi-opt/build.sh` | host (no GPU) wrappers, mode fixed. |
| `hdf5-subfiling/build.sh` | `[dbg\|opt] [host\|cuda\|rocm]` – HDF5 with parallel + subfiling + Fortran. |
| `phare-mpi-*/clean_builds.sh`, `clean_all.sh` | remove build trees / also downloaded sources. |
| `.github/scripts/check_linkage.sh` | `PREFIX [ALLOWED...]` – fails if anything under `PREFIX` links MPI-stack libs from elsewhere. |
| `phare-hdf5-dbg/`, `phare-hdf5-gpu/` | older HDF5 scripts, superseded by `hdf5-subfiling/`. |

## Environment variables

| Variable | Used by | Default |
|---|---|---|
| `WORK_DIR` | `build_stack.sh` | `<repo>/work` |
| `SRC_DIR` | all | `$WORK_DIR/src`, or the calling script's directory |
| `BUILD_ROOT` | all | `$WORK_DIR/build`, or the calling script's directory |
| `MPI_INSTALL_DIR`, `HDF5_INSTALL_DIR` | `build_stack.sh` | `/opt/mpi/<flavor>-<mode>`, `/opt/mpi/hdf5-subfiling-<flavor>-<mode>` |
| `INSTALL_DIR` | individual scripts | as above |
| `MPI` | `hdf5-subfiling/build.sh` | `/opt/mpi/<flavor>-<mode>` |
| `NPROC` | all | all cores |
| `MPI_VER`, `PMIX_VER`, `UCX_VER` | `build_mpi.sh` | see top of `build_mpi.sh` |
| `HDF5_VER` | `hdf5-subfiling/build.sh` | see script; set empty for the default branch |
| `CUDA_ROOT`, `ROCM_ROOT` | `build_mpi.sh` | `/usr/local/cuda`, `/opt/rocm` |

Source trees are named by version (`pmix-v5.0.11`, `ucx-v1.22.0`, `openmpi-5.0.11`, `hdf5-2.2.0`)
and all builds are out of tree, so one `SRC_DIR` / `BUILD_ROOT` can be shared by every flavor and
mode. Build trees are `build-<flavor>-<mode>` / `build-hdf5-<flavor>-<mode>`, and logs are
`.<flavor>-<mode>.<pkg>.sh.{out,err}` in `BUILD_ROOT`.

Flags: `dbg` = `-g3 -O3 -march=native -mtune=native -fno-omit-frame-pointer` (HDF5 `Debug`),
`opt` = `-DNDEBUG -g0 -O3 -march=native -mtune=native` (HDF5 `Release`). Because of
`-march=native`, build on (or for) the machine you run on.

## Updating versions

Use the newest **stable** release of each library that is compatible with the others. Pre-releases
and release candidates are skipped.

1. **Open MPI**: latest stable from <https://www.open-mpi.org/software/ompi/> (tags:
   `gh api repos/open-mpi/ompi/tags -q '.[].name'`). Set `MPI_VER` in `build_mpi.sh`.
   The download URL follows from the version (`v${MPI_VER%.*}`), so a new series needs no other edit.
2. **PMIx**: match the version Open MPI bundles, not just the newest PMIx. Look up the bundled
   submodule commits and compare them with PMIx/PRRTE tags:
   ```bash
   gh api "repos/open-mpi/ompi/contents/3rd-party?ref=v$MPI_VER" -q '.[] | "\(.name) \(.sha)"'
   gh api repos/openpmix/openpmix/commits/v5.0.11 -q .sha   # find the tag with the same sha
   ```
   A newer PMIx series (e.g. 6.x) goes with a newer PRRTE and Open MPI series. Move all three
   together, once that Open MPI is stable.
3. **UCX**: latest non-prerelease from `gh release list --repo openucx/ucx`.
4. **HDF5**: latest from `gh release list --repo HDFGroup/hdf5`. Set the default `HDF5_VER` in
   `hdf5-subfiling/build.sh`. If the CMake options change, check `CMakeBuildOptions.cmake` and
   `CMakeLists.txt` for `HDF5_ENABLE_PARALLEL`, `HDF5_ENABLE_SUBFILING_VFD` and `HDF5_BUILD_FORTRAN`.
5. Push to a PR and let CI build it. Locally, `./build_stack.sh` then reuses the downloads
   in `SRC_DIR` and only fetches the new versions.

## CI

`.github/workflows/ci.yml` runs on every PR:

- `lint`: `shellcheck` and `shfmt -i 4 -d` over all scripts. Run `shfmt -i 4 -w` locally to fix
  formatting.
- `host` (fedora:43), `cuda` (fedora:43 + NVIDIA's `fedora43` dnf repo, minimal toolkit) and
  `rocm` (`rocm/dev-ubuntu-24.04`), each for `dbg` and `opt`. They build MPI and HDF5 and run the
  linkage check. `host` also runs HDF5's subfiling tests. Runners have no GPU, so `cuda` and `rocm`
  only build and link.
- The distro's own `pmix`/`ucx` packages are installed on purpose. If our build picks them up
  instead of its own, the linkage check fails.
- Build logs and `config.log`s are uploaded as artifacts when a job fails.

When bumping CUDA or ROCm, check that the image tag or repo package exists. NVIDIA's `fedora43`
repo can lag behind the latest CUDA. List it with
`curl -s https://developer.download.nvidia.com/compute/cuda/repos/fedora43/x86_64/ | grep -oE 'cuda-nvcc-[0-9]+-[0-9]+' | sort -uV`.

## Known gotchas

- **Use the Open MPI release tarball, not a GitHub tag archive.** The tarball is `make dist` output:
  it contains the generated `configure`, the bundled PMIx/PRRTE and prebuilt docs (hence
  `--disable-sphinx`). A tag archive has none of these.
- **UCX always builds with `-Werror`** (hardcoded, no configure switch). New compilers bring new
  warnings. Old UCX (≤1.17) fails on GCC 15 / C23, and GCC 13 gives a false positive
  `maybe-uninitialized`, which `build_mpi.sh` downgrades with `-Wno-error=maybe-uninitialized`.
  If a new compiler breaks UCX, prefer bumping UCX. Otherwise add a narrow `-Wno-error=<x>` there.
- **Mixed libraries**: if an application picks up a system `libpmix`/`libucx`, run
  `./.github/scripts/check_linkage.sh <prefix>` on the install, and `ldd` on the application.
