#!/bin/bash

# Version: 0.34
# Author: Le Yan

# To-do
# 1. Allow mixed node types (2 and 4 devices per node).
# 2. Allow multiple node runs for the OOD portal app.
# 3. Handle the failed sequences automatically (remove the rerun mode).
# 4. Add more command line options.
# 5. More sanity checks (e.g. availability of GPUs, reference data etc.)

#version 0.33

#Fixed the bug where fasta files prepared on Windows may have extra characters that may cause the job to fail.

#version 0.34

#Adjust the number of GNU parallel jobs according to the number of devices per node.

usage() {
  cat << HERE

  Description:
    This scripts process protein sequences (in fasta format) using the AlphaFold package 
    developed by DeepMind. For monomer models, it will read the sequences from all fasta 
    files located in the same directory, store each sequence in a separate fasta file, 
    then process them with Alphafold (from within a Singularity container). For multimer 
    models, each fasta file will be processed separately.
    
  Requirements:
    Access to the reference datasets.
    GNU parallel must be in the PATH.

  Usage:
    $0 --model [monomer|multimer] --mode [[run|rerun] <options>
    where the mandatory flags are:
      --model
        Users need to choose either the monomer or multimer model.
      -- mode
        the "run" mode is to process the sequences contained in all FASTA files in the current directory, and
        the "rerun" mode is to process any sequences that are not processed in the workspace.

  Options:
    --inputdir: the directory where the input fasta files are located. If not provided, the current directory will be use.
    --dryrun: quit after sanity checks and run setup.
    -v: run in the verbose mode (for debugging).
    -h: print help message.

  Examples:
    $0 --model monomer --mode run --inputdir /path/to/the/fasta/files

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

if [[ "$#" -eq 0 ]]
then
  usage
  exit
fi

# Set initial valules.
dryrun=0
unset model
unset mode
unset inputdir

# Process command line arguments.

while [ "$#" -gt 0 ] ; do
case "$1" in
  --model)
        model=$2;
        shift 2;;
  --mode)
        mode=$2;
        shift 2;;
  --inputdir)
        inputdir=$2;
        shift 2;;
  --dryrun)
        dryrun=1;
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

# Get the directory where the scripts are loated.
execdir=$(readlink -f $(dirname $0))

# Perform the sanity checks.

if [ "$mode" != 'run' ] && [ "$mode" != 'rerun' ]
then
  quit_on_error "The mode must be specified as either 'run' or 'rerun'."
fi

if [ "$model" != 'monomer' ] && [ "$model" != 'multimer' ]
then
  quit_on_error "The model must be specified as either 'monomer' or 'multimer'."
fi

# Check if GNU parallel is in PATH.
if ! [[ -x "$(command -v parallel)" ]]
then
  quit_on_error "GNU parallel could not be found!"
fi

# Check if the input directory exists.

if [[ -z "$inputdir" ]]
then
  inputdir=$(pwd)
fi

if [[ ! -d $inputdir ]] 
then
  quit_on_error "Please check the input directory $inputdir."
fi

cd $inputdir

if [ "$mode" == "run" ]
then

  # Make sure the workspace is not already there.
  if [ -d "workspace" ]
  then
    quit_on_error "We are in the run mode, but the workspace already exists. Rerun maybe?"
  fi

  mkdir workspace

fi

if [ "$mode" == "rerun" ]
then

  # Check if the workspace directory is there.
  if [ ! -d "workspace" ]
  then
    quit_on_error "We are in the rerun mode, but the workspace does not exist."
  fi

fi


# Set up the monomer model.
if [ "$model" == "monomer" ]
then

  # Find the number of CUDA devices on each node
  ncudadevices=$(nvidia-smi -L | wc -l)
  topdevice=$(( $ncudadevices - 1 ))
  devlist=$(seq 0 $topdevice)

  # Check if the foldsingle.sh script exists.
  if [[ ! -f "$execdir/foldsingle.sh" ]]
  then
    quit_on_error "The foldsingle.sh is not found under $execdir. Quitting."
  fi

  # The run mode.
  if [ "$mode" == "run" ]
  then

    # Merge all fasta files into one.
    for file in `ls *.fasta`
    do
      cat $file >> workspace/merged_usr.fasta
    done
    sed -i -e 's/\r/\n/g' workspace/merged_usr.fasta
    tr -cd '\11\12\15\40-\176' < workspace/merged_usr.fasta > workspace/merged.fasta
    rm workspace/merged_usr.fasta

    nseq=$(grep '>' workspace/merged.fasta | wc -l)
    if [ $nseq -gt 9999 ]
    then
      quit_on_error "Found more than 9,999 sequences. Please consider break them up into multiple jobs."
    fi

    # Copy the foldsingle script to the workspace.
    cd workspace
    BASEDIR=$(pwd)
    cp $execdir/foldsingle.sh .

    # Split the fasta files - up to 10,000 sequences.
    awk '/^>/ {if(x>0) close(outname); x++; outname=sprintf("target_%.4d.fasta",x); print > outname;next;} {if(x>0) print >> outname;}' merged.fasta
    rm merged.fasta

    # Prepare the input list for GNU Parallel
    for fasta in `ls *.fasta`
    do
      echo $BASEDIR/$fasta >> input.lst
    done
  
  # The run mode ends here.
  fi

  # The rerun mode.
  if [ "$mode" == "rerun" ]
  then

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
      if [ ! -d $dname ]
      then
        echo $BASEDIR/$dname.fasta >> input.lst
      fi
    done

  # The rerun mode ends here.
  fi

  if [ "$dryrun" == "1" ] 
  then
    echo Dry run done.
    exit 0
  fi

  nseq=$(cat input.lst | wc -l)

  # Try to figure out whether we are using Slurm or Torque.
  if [ -z "$SLURM_JOB_NODELIST" ]
  then
    hostfile=$PBS_NODEFILE
  else
    scontrol show hostnames $SLURM_JOB_NODELIST > slurm.hosts
    hostfile="$BASEDIR/slurm.hosts"
  fi
  nnode=$(cat $hostfile | uniq | wc -l)

  echo
  echo "Start processing $nseq sequences on $nnode nodes."
  echo "Each node has $ncudadevices GPUs."
  echo 

  # Process all sequences with AlphaFold
  parallel -j $ncudadevices --delay 30 --slf $hostfile --workdir $BASEDIR --link "$BASEDIR/foldsingle.sh {} $BASEDIR; sleep 120" :::: input.lst ::: $devlist 

# End of the monomer model.
fi

if [ "$model" == "multimer" ]
then

  # Check if the foldmultiple.sh script exists.
  if [[ ! -f "$execdir/foldmultiple.sh" ]]
  then
    quit_on_error "The foldmultiple.sh is not found under $execdir. Quitting."
  fi

  # The run mode.
  if [ "$mode" == "run" ]
  then

    # Copy all fasta files into the work directory.
    nfile=`ls *.fasta | wc -l`
    for file in `ls *.fasta`
    do
      sed -i -e 's/\r/\n/g' $file
      tr -cd '\11\12\15\40-\176' < $file > workspace/$file
    done

    cd workspace
    BASEDIR=$(pwd)
    cp $execdir/foldmultiple.sh .

    # Prepare the input list for GNU Parallel
    for fasta in `ls *.fasta`
    do
      echo $BASEDIR/$fasta >> input.lst
    done

  # The run mode ends here.
  fi

  # The rerun mode.
  if [ "$mode" == "rerun" ]
  then

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
      if [ ! -d $dname ]
      then
        echo $BASEDIR/$dname.fasta >> input.lst
      fi
    done

  # Teh rerun mode ends here.
  fi

  if [ "$dryrun" == "1" ]
  then
    echo Dry run done.
    exit 0
  fi

  # Try to figure out whether we are using Slurm or Torque.
  if [ -z "$SLURM_JOB_NODELIST" ]
  then
    hostfile=$PBS_NODEFILE
  else
    scontrol show hostnames $SLURM_JOB_NODELIST > slurm.hosts
    hostfile="$BASEDIR/slurm.hosts"
  fi
  nnode=$(cat $hostfile | uniq | wc -l)

  echo
  echo "Start processing $nfile fasta files on $nnode nodes."
  echo 

  # Process all sequences with AlphaFold
  parallel -j 1 --delay 30 --slf $hostfile --workdir $BASEDIR --link "$BASEDIR/foldmultiple.sh {} $BASEDIR; sleep 120" :::: input.lst 

# End of the multimer model.
fi


# Process all sequences with AlphaFold
#parallel -j 2 --delay 30 --slf $hostfile --workdir $BASEDIR --link "$BASEDIR/foldsingle.sh {} $BASEDIR; sleep 120" :::: input.lst ::: 0 1
#parallel -j 1 --delay 30 --slf $PBS_NODEFILE --workdir $BASEDIR $BASEDIR/foldsingle.sh {} $BASEDIR :::: input.lst
#parallel -j 2 --slf $PBS_NODEFILE --workdir $BASEDIR --link echo "./foldsingle.sh" {} $BASEDIR :::: input.lst ::: 0 1
