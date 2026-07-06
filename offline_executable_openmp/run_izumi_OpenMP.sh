#!/bin/bash
#PBS -N CLMml_CHATS7_log_openMP_OneThread
#PBS -A CESM0029
#PBS -q medium
#PBS -l select=1:ncpus=1:mem=32GB
#PBS -l walltime=00:30:00
#PBS -j oe
#PBS -l job_priority=regular

set -euo pipefail

module --force purge

module load compiler/intel/20.0.1
module load mpi/2.3.3/intel/20.0.1
module load openmpi/4.0.3/intel/20.0.1
module load tool/hdf5/1.12.0/intel/20.0.1
module load tool/netcdf/4.7.4/intel/20.0.1

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR"

HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "nohash")
DATETIME=$(date +"%Y%m%d_%H%M%S")
LOGFILE="run.${HASH}.${DATETIME}_OpenMP_OneThread.log"

mkdir -p obj

echo "Cleaning previous builds..."
make -f Makefile_izumi clean
echo "Building the executable..."
make -f Makefile_izumi
echo "Running the executable with OpenMP..."

export OMP_STACKSIZE=8G
export OMP_NUM_THREADS=1
stdbuf -oL -eL ./prgm.exe < nl.all_CHATS7.05.2007 > "$LOGFILE" 2>&1
