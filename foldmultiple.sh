#!/bin/bash

# Process a single fasta file (multiple sequences) with AlphaFold (from a container)

# Usage: foldmultiple.sh <name of the fasta file> <output directory)

ALPHAFOLD_DATA_PATH=/work/lyan1/projects/alphafold/alldata

#SIF=/project/lyan1/projects/singularity/alphafold/alphafold-catgumag-2.2.sif
#SIF=/home/admin/singularity/alphafold-2.1-cuda11-cudnn8.sif
SIF=/home/admin/singularity/alphafold-catgumag-2.2.sif

FASTA=$1
MODEL=multimer
#DEVICE=$2
OUTDIR=$2

singularity exec --env NVIDIA_VISIBLE_DEVICES='all',TF_FORCE_UNIFIED_MEMORY='1',XLA_PYTHON_CLIENT_MEM_FRACTION='4.0' -B $ALPHAFOLD_DATA_PATH:/data -B /work -B /project -B .:/etc --pwd /app/alphafold --nv $SIF python3 /app/alphafold/run_alphafold.py \
    --fasta_paths=$FASTA \
    --output_dir=$OUTDIR \
    --model_preset=$MODEL \
    --db_preset=full_dbs \
    --max_template_date=2021-12-01 \
    --use_gpu_relax=1 \
    --data_dir=/data \
    --uniref90_database_path=/data/uniref90/uniref90.fasta \
    --mgnify_database_path=/data/mgnify/mgy_clusters.fa \
    --uniclust30_database_path=/data/uniclust30/uniclust30_2018_08/uniclust30_2018_08 \
    --bfd_database_path=/data/bfd/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt \
    --template_mmcif_dir=/data/pdb_mmcif/mmcif_files \
    --obsolete_pdbs_path=/data/pdb_mmcif/obsolete.dat \
    --pdb_seqres_database_path=/data/pdb_seqres/pdb_seqres.txt \
    --uniprot_database_path=/data/uniprot/uniprot.fasta \
    --stderrthreshold='debug' \
    --verbosity=1 \
    --num_multimer_predictions_per_model=2
