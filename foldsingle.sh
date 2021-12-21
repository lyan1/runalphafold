#!/bin/bash

# Process a single sequence with AlphaFold (from a container)

# Usage: foldsingle.sh <name of the fasta file> <device id> <output directory)

ALPHAFOLD_DATA_PATH=/work/lyan1/projects/alphafold/alldata

#SIF=/project/lyan1/projects/singularity/alphafold/alphafold-jupyter.sif
#SIF=/project/lyan1/projects/singularity/alphafold/alphafold-sandbox
#SIF=/project/lyan1/projects/singularity/alphafold/alphafold-catgumag.sif
SIF=/home/admin/singularity/alphafold-2.1-cuda11-cudnn8.sif

FASTA=$1
MODEL=monomer
DEVICE=$2
OUTDIR=$3

singularity exec --env CUDA_VISIBLE_DEVICES=$DEVICE -B $ALPHAFOLD_DATA_PATH:/data -B /project -B .:/etc --pwd /app/alphafold --nv $SIF python3 /app/alphafold/run_alphafold.py \
    --fasta_paths=$FASTA \
    --output_dir=$OUTDIR \
    --model_preset=$MODEL \
    --db_preset=full_dbs \
    --max_template_date=2021-12-01 \
    --data_dir=/data \
    --uniref90_database_path=/data/uniref90/uniref90.fasta \
    --mgnify_database_path=/data/mgnify/mgy_clusters.fa \
    --uniclust30_database_path=/data/uniclust30/uniclust30_2018_08/uniclust30_2018_08 \
    --bfd_database_path=/data/bfd/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt \
    --pdb70_database_path=/data/pdb70/pdb70 \
    --template_mmcif_dir=/data/pdb_mmcif/mmcif_files \
    --obsolete_pdbs_path=/data/pdb_mmcif/obsolete.dat \
    --stderrthreshold='debug' \
    --verbosity=1
