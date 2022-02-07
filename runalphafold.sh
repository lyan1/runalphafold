#!/bin/bash

# Version: 0.2
# Author: Le Yan

# To-do
# 1. Adjust the number of GNU parallel jobs according to the number of devices per node.
# 2. Add more command line options
# 4. More sanity checks (e.g. availability of GPUs, reference data etc.)

usage() {
  cat << HERE

  Description:
    This scripts process protein sequences (in fasta format) using the AlphaFold package 
    developed by DeepMind. It will read the sequences from all fasta files located in 
    the same directory, store each sequence in a separate fasta file, then process them
    with Alphafold (from within a Singularity container).
    
    Note: only the monomer model is supported at the moment.

  Requirement:
    Access to the reference datasets.
    GNU parallel must be in the PATH.

  Usage:
    $0 [run|rerun] <options>
    where
      the "run" mode is to process the sequences contained in all FASTA files in the current directory, and
      the "rerun" mode is to process any sequences that are not processed in the workspace.

  Options:
    -v: run in the verbose mode (for debugging)
    -h: print help message

HERE
}

function quit_on_error {
  echo
  echo Error: $1
  echo
  exit 1
}

function debug_message {
  echo 
  echo $1
  echo
}

unset mode

if [[ "$#" -eq 0 ]]
then
  usage
  exit
fi

# Process command line arguments.

while [ "$#" -gt 0 ] ; do
case "$1" in
  run)
        mode="run";
        shift 1;;
  rerun)
        mode="rerun";
        shift 1;;
  -v)
        verbose=1;
        shift;;
  -h)
        usage
        exit
        ;;
  *)
        echo 
        echo "Invalid option: $1"
        echo
        usage
        exit
        ;;
esac
done

# Perform the sanity checks.

# Check if the mode is correctly specified.
#if [ "$mode" != 'single' ] && [ "$mode" != 'multiple' ] && [ "$mode" != 'rerun' ] 
#then
#  quit_on_error "The mode should either single, multiple, or rerun."
#fi

# Check if the foldsingle.sh script exists.
if [[ ! -f "foldsingle.sh" ]]
then
  quit_on_error "The foldsingle.sh is not found. Quitting." 
fi

# Check if GNU parallel is in PATH.
if ! [[ -x "$(command -v parallel)" ]]
then
  quit_on_error "GNU parallel could not be found!"
fi

# The run mode.

if [ "$mode" == "run" ]
then

  # Make sure the workspace is not already there.
  if [ -d "workspace" ] 
  then
    quit_on_error "We are in the run mode, but the workspace already exists. Rerun maybe?"
  fi

  mkdir workspace

  # Merge all fasta files into one.
  for file in `ls *.fasta` 
  do
    cat $file >> workspace/merged.fasta
  done

  nseq=$(grep '>' workspace/merged.fasta | wc -l)
  if [ $nseq -gt 9999 ] 
  then 
    quit_on_error "Found more than 9,999 sequences. Please consider break them up into multiple jobs."
  fi

  # Copy the foldsingle script to the workspace.
  cd workspace
  BASEDIR=$(pwd)
  cp ../foldsingle.sh .

  # Split the fasta files - up to 10,000 sequences.
  awk '/^>/ {if(x>0) close(outname); x++; outname=sprintf("target_%.4d.fasta",x); print > outname;next;} {if(x>0) print >> outname;}' merged.fasta
  rm merged.fasta

  # Prepare the input list for GNU Parallel
  for fasta in `ls *.fasta` 
  do
    echo $BASEDIR/$fasta >> input.lst
  done

fi

# The rerun mode.

if [ "$mode" == "rerun" ]
then

  # Check if the workspace directory is there.
  if [ ! -d "workspace" ]
  then
    quit_on_error "We are in the rerun mode, but the workspace does not exist."
  fi

  cd workspace
  BASEDIR=$(pwd)

  # Check if the input list exists.
  if [ -f "input.lst" ]
  then
    mv input.lst input.lst.bkp
  fi

  # Create the new input list from the sequences that are not processed.
  for ffile in `ls *.fasta`
  do
    dname="${ffile%.*}"
#    echo $dname
    if [ ! -d $dname ]
    then
      echo $BASEDIR/$dname.fasta >> input.lst
    fi
  done

fi

# Try to figure out whether we are using Slurm or Torque.
if [ -z "$SLURM_JOB_NODELIST" ]
then
  hostfile=$PBS_NODEFILE
else
  scontrol show hostnames $SLURM_JOB_NODELIST > slurm.hosts
  hostfile="$BASEDIR/slurm.hosts"
fi

nseq=$(cat input.lst | wc -l)
nnode=$(cat $hostfile | uniq | wc -l)

echo
echo "Start processing $nseq sequences on $nnode nodes."
echo 

# Process all sequences with AlphaFold
parallel -j 2 --delay 30 --slf $hostfile --workdir $BASEDIR --link "$BASEDIR/foldsingle.sh {} $BASEDIR; sleep 120" :::: input.lst ::: 0 1
#parallel -j 1 --delay 30 --slf $PBS_NODEFILE --workdir $BASEDIR $BASEDIR/foldsingle.sh {} $BASEDIR :::: input.lst
#parallel -j 2 --slf $PBS_NODEFILE --workdir $BASEDIR --link echo "./foldsingle.sh" {} $BASEDIR :::: input.lst ::: 0 1
