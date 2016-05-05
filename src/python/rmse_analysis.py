"""
This is a rewrite of rmse_analysis.R and empirical_rmse_analysis.R

Why? It's difficult to assess the correctness of R code (for me)
It's also very slow

We do not do plotting here, leaving that for make_plots.R and empirical_make_plots.R

We output k_df and rmse_df, however.

For the data frame creation process, we want to store in the following format:
    (this is called a 'record' in pandas)
    [{'col1': val, 'col2': val}, {'col1': val, 'col2': val}]
    In other words, we suppress the index and store each row as a dict

    If we have a df, we do:
    r = df.to_dict('records')

    To recover the df (minus the index), we do:
    pd.DataFrame.from_dict(r)

We get rid of the 'observed' lingo, instead using 'cm' for correctly measured
"""
import os
import glob
import pandas as pd

def sim_run_fnames_iter(results_path):
    """
    Give this the folder where sim runs are stored
    It yeilds sim run filenames one by one
    """
    file_set = set(os.listdir(sim_path))
    file_set.remove('.DS_Store')
    for sim_run_fname in file_set:
        yield sim_run_fname

def params_from_fname(sim_run_fname):
    """
    Takes sim run file (with the run number)
        e.g.: e_N_0_15.0__c_10.0_N_N__empirical_5.0_N_N___American75_gc~7
    Returns a dict of params: {'this': 'that'}
    """
    params = {}
    s = sim_run_fname.strip('.csv')
    s, run_num = s.split('~') # get run num
    params['run_num'] = run_num
    eq, g = s.split('___') # split into threshold eq and graph param parts
    eq_list = eq.split('__')

    # parse threshold equation here
    vcount = 1 #increment non-constant and non-epsilon vars
    for var in eq_list:
        var_list = var.split('_')
        # order ['distribution', 'coefficient', 'mean', 'sd']
        distribution = var_list[0]
        coefficient = var_list[1]
        mean = var_list[2]
        sd = var_list[3]
        if distribution == 'c':
            params['constant'] = float(coefficient)
        elif distribution == 'e':
            params['error_sd'] = float(sd)
        else:
            vname = 'var{}'.format(vcount)
            params[vname + '_' + 'coef'] = float(coefficient)
            params[vname + '_' + 'sd'] = float(sd)
            vcount += 1
    # parse graph params here
    g_list = g.split('__')
    if len(g_list) == 4:
        # for sim
        params['mean_deg'] = float(g_list[0])
        params['graph_size'] = float(g_list[1])
        params['graph_type'] = g_list[2]
        params['graph_param'] = float(g_list[3])
    else:
        # for empirical
        params['sim_network'] = g
    return params

def process_rmse(sim_df):
    """
    This function does the RMSE analysis for one sim run
    We take the sim_df as an input, which is the df for one simulation run
    Want to output the following:
        num_active
        cm_num
        cm_epsilon_mean
        cm_cons_ols
        cm_beta_ols
        cm_rmse
        true_cons
        true_beta
        true_rmse
        naive_rmse
    """
    pass

def process_k(sim_df):
    pass

def process_sim_run(sim_run_fname):
    """
    processes one run of sim, just saves us from opening the file twice
    """
    sim_param_dict = params_from_fname(sim_run_fname) # parse params

    sim_df = pd.read_csv(sim_run_fname) # read file
    rmse_dict = process_rmse(sim_df)
    k_dict = process_k(sim_df)
    rmse_dict.update(sim_param_dict)
    k_dict.update(sim_param_dict)
    return rmse_dict, k_dict

def process_batches(results_path):
    """
    Goes through batches in an organized way
    Returns two dfs with the data we need
    This is a little different from the original R file:
        We don't do the aggregation within runs here
        We have one line per sim run, not one line per batch
    """
    rmse_list = []
    k_list = []
    for sim_run_fname in sim_run_fnames_iter(results_path):
        rmse_dict, k_dict = process_sim_run(sim_run_fname)
        rmse_list.append(rmse_dict)
        k_list.append(k_dict)
    rmse_df = pd.DataFrame.from_dict(rmse_list)
    k_df = pd.DataFrame.from_dict(k_list)
    return rmse_df, k_df

if __name__ == '__main__':
    SIM_PATH = ''
    K_DF_PATH = ''
    RMSE_DF_PATH = ''

    rmse_df, k_df = process_batches(batches)
    rmse_df.to_csv(RMSE_DF_PATH)
    k_df.to_csv(K_DF_PATH)
