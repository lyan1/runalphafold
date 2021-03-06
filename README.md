# runalphafold
Wrapper script for running Alphafold on LSU HPC clusters

# Purpose

This script batch-processes protein sequences (in fasta format) using the AlphaFold package developed by DeepMind. For monomer models, it will read the sequences from all fasta files located in the same directory, store each sequence in a separate fasta file, then process them with Alphafold (from within a Singularity container). For multimer models, each fasta file will be processed separately.    
# Files

- `runalphafold.sh`: the main script
- `foldsingle.sh`: the script that is called from the main script to process one single sequence.
- `foldmultiple.sh`: the script that is called from the main script to run the multimer model on one single fasta file.
- `af2.pbs`: a sample PBS job script (for the SuperMIC cluster)
- `af2.slurm`: a sample Slurm job script (for the Deep Bayou cluster)

# How to use

Note: 
- This script only works on the LSU HPC SuperMIC and Deep Bayou clusters at the moment.
- GNU parallel needs to be in your path (adding `module add parallel` to the `.modules` file should take care of it).

## Steps

1. Place all three scripts in the same directory with all the fasta files. The `af2.pbs` and `af2.slurm` job scripts are optional and only necessary if you are running the job through a PBS or Slurm job manager;
2. Run the `./runalphafold.sh` script from that directory with the syntax `./runalphafold.sh --model [monomer|multimer] --mode [[run|rerun]`:
    - `--model [monomer|multimer]: choose either the monomer or the multmer model
    - `--mode [run|rerun]`:
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

, where 
- For the monomer model, each of the *.fasta files contains one sequence and the directory with the same name the output files from AlphaFold.
- For the multimer model, each directory contains the output files for the sequences in the fasta file with the same name.

