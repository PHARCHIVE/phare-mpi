#!/usr/bin/env bash
set -ex

ompi_info --parsable --all | grep mpi_built_with_cuda_support:value
