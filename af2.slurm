#!/bin/bash

#SBATCH -A hpc_deepbayou
#SBATCH -t 12:00:00
#SBATCH -N 2
#SBATCH -p checkpt
#SBATCH -J AF2.test.multi

JOBDIR=`pwd`

./runalphafold.sh --model multimer --mode run
