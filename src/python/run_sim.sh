mkdir -p ../../data/sim_replicants
mkdir -p ../../data/empirical_replicants

python sim_param_space.py
python empirical_param_space.py

python sim_thresholds.py
python empirical_thresholds.py

python rmse_analysis.py
