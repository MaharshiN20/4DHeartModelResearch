#!/bin/bash
#SBATCH --job-name=4DHeartModel_EAE
#SBATCH --account=sua193
#SBATCH --partition=compute
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=10
#SBATCH --mem=60G
#SBATCH --time=04:00:00
#SBATCH --output=/home/mnaik/expanse/training_eae_%j.log
#SBATCH --error=/home/mnaik/expanse/training_eae_%j.err

ulimit -c 0  # Disable core dumps
module load gcc/10.2.0
module load python/3.8.12

export VTK_LOG_VERBOSITY=ERROR
export VTK_OFFSCREEN_RENDERING=1
export DISPLAY=

cd /home/mnaik/expanse/4DHeartModel_trimesh
source myenv_trimesh/bin/activate
python3 run_generative_heart_model.py source/configs/generative_model --mode=dhb_eae
