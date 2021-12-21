# runalphafold
Wrapper script for running Alphafold on LSU HPC clusters

# Purpose

This script processes protein sequences (in fasta format) using the AlphaFold package developed by DeepMind. It will read the sequences from all fasta files located in the same directory, store each sequence in a separate fasta file, then process them with Alphafold (from within a Singularity container).
    
# Files

- `runalphafold.sh`: the main script
- `foldsingle.sh`: the script that is called from the main script to process one single sequence
- `af2.pbs`: a sample PBS job script 

# How to use

Note: 
- This script only works on the LSU HPC SuperMIC cluster at the moment.
- GNU parallel needs to be in your path (adding `module add parallel` to the `.modules` file on SuperMIC should take care of it).

1. Put `runalphafold.sh` and `foldsing.sh` in the same directory with all the fasta files. The `af2.pbs` is optional and is only necessary if you are running the job thourhg a PBS job manager;
2. Run `./runalphafold.sh run` or `./runalphafold.sh rerun` from that directory, depending which mode you'd like to run:
- `run`: process the sequences contained in all FASTA files in the current directory
- `rerun`: when processing a large amount of sequences, there is a chance that a small number may fail. If that happens, use this rerun mode to find those sequences and process them.

After the jobs finishes, there should be a `workspace` directory, in which you can find:

    target_0001
    target_0001.fasta
    target_0002
    target_0002.fasta
    target_0003
    target_0003.fasta
  ...

, where each of the target_*.fasta files contains one sequence and the directory with the same name the output files from AlphaFold.

