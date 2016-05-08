mkdir -p /Users/g/Desktop/data/sim_replicants
mkdir -p /Users/g/Desktop/data/empirical_replicants

python python/sim_param_space.py
python python/empirical_param_space.py

python python/sim_thresholds.py
python python/empirical_thresholds.py

python python/rmse_analysis.py
