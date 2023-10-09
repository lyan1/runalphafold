# runalphafold
Wrapper script for running Alphafold on LSU HPC clusters

# Purpose

This script batch-processes protein sequences (in fasta format) using the AlphaFold package developed by DeepMind. For monomer models, it will read the sequences from all fasta files located in the same directory, store each sequence in a separate fasta file, then process them with Alphafold (from within a Singularity container). For multimer models, each fasta file will be processed separately.    
# Files

- `runalphafold.sh`: the main script
- `foldsingle.sh`: the script that is called from the main script to process one single sequence.
- `foldmultiple.sh`: the script that is called from the main script to run the multimer model on one single fasta file.
- `af2.pbs`: a sample PBS job script (for the SuperMIC cluster)
- `af2.slurm`: a sample Slurm job script (for the Deep Bayou and SuperMike-3 clusters)

# How to use

Note: 
- This script works on the LSU HPC SuperMIC, Deep Bayou, and SuperMike-3 clusters.
- **GNU parallel needs to be in your path (adding `module add parallel` to the `.modules` file under your home directory should take care of it).**

## Steps

1. Place all three scripts in the same directory with all the fasta files. The `af2.pbs` and `af2.slurm` job scripts are optional and only necessary if you are running the job through a PBS or Slurm job manager;

Alternatively, you can add `module add runalphafold` to the `.modules` file under your home directory. This way you can run `runalphafold.sh` from any directory without placing those three scripts there. 

2. Run the `runalphafold.sh` script from that directory with the syntax `./runalphafold.sh --model [monomer|multimer]`:
    - `--model [monomer|multimer]: choose either the monomer or the multmer model

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
