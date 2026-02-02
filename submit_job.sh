#!/bin/bash
#SBATCH --job-name=resnet18-cifar10
#SBATCH --account=jungaocv0   
#SBATCH --partition=spgpu             
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4            
#SBATCH --gres=gpu:1
#SBATCH --mem-per-cpu=11GB
#SBATCH --time=02:00:00              
#SBATCH --output=logs/%x-%j.out
#SBATCH --error=logs/%x-%j.err

module load gcc
module load cuda
module load cudnn

# Initialize Conda for non-interactive shells
source "$HOME/miniconda3/etc/profile.d/conda.sh"

source activate resnet
python train.py 
