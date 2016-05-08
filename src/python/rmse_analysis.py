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
import sys
import glob
import pandas as pd
from math import sqrt
from sklearn import linear_model
from sklearn.metrics import mean_squared_error
from constants import *

def sim_run_fnames_iter(sim_run_path):
    """
    Give this the folder where sim runs are stored
    It yeilds sim run filenames one by one
    """
    file_set = set(os.listdir(sim_run_path))
    if '.DS_Store' in file_set:
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
    if sim_run_fname.endswith('.csv'):
        s = sim_run_fname[:-4]
    else:
        s = sim_run_fname
    s, run_num = s.split('~') # get run num
    params['run_num'] = run_num
    eq, g = s.split('___') # split into threshold eq and graph param parts
    eq_list = eq.split('__')

    # parse threshold equation here
    vcount = 1 #increment non-constant and non-epsilon vars
    for var in eq_list:
        var_list = var.split('_')
        # order ['distribution', 'coefficient', 'mean', 'sd']
        distribution = var_list[0].replace('-', '.')
        coefficient = var_list[1].replace('-', '.')
        mean = var_list[2].replace('-', '.')
        sd = var_list[3].replace('-', '.')
        if distribution == 'c':
            params['constant'] = float(coefficient)
        elif distribution == 'e':
            params['error_sd'] = float(sd)
        else:
            vname = 'var{}'.format(vcount)
            params[vname + '_' + 'coef'] = float(coefficient)
            if not EMPIRICAL:
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
    The sim_df has the following columns
        name,
        activated,
        threshold,
        before_activation_alters,
        after_activation_alters,
        degree,
        observed,
        var1,
        activation_order,
        epsilon
        ...

    One subtlety:
        We get r^2 for the in-sample model
        But we do RMSE for using the model to predict for everyone
        RMSE is our way of quantifying prediction error,
        While r^2 gives us a metric for comparing explained variance

    Output the following:
        cm_num
        cm_epsilon_mean
        cm_cons_ols
        cm_beta_ols
        cm_r2
        cm_rmse
        active_num
        active_epsilon_mean
        active_cons
        active_beta
        active_r2
        active_rmse
        all_num
        all_epsilon_mean
        all_cons
        all_beta
        all_r2
        all_rmse
        naive_rmse

    The CM set is what we want to argue works well
    The activated set is the basis for comparison (cm > activated)
    We have the true relationship in the data for comparison
    """
    sim_df['constant'] = 1
    all_X = sim_df[['constant', 'var1']]
    true_y = sim_df['threshold']
    rmse_dict = {}
    # these are cols we keep when chopping up sim_df
    relevant_cols = [
        'threshold',
        'after_activation_alters',
        'constant',
        'var1',
        'epsilon',
    ]
    #### cm_df processing here ###############################################
    cm_df = sim_df.loc[sim_df['observed'] == 1, relevant_cols]
    cm_y = cm_df['after_activation_alters']
    cm_X = cm_df[['constant', 'var1']]
    cm_reg = linear_model.LinearRegression(fit_intercept=False)
    cm_reg.fit(cm_X, cm_y)
    # in-sample r-squared
    cm_r2 = cm_reg.score(cm_X, cm_y)
    # use this model to predict for all
    cm_rmse = sqrt(
        mean_squared_error(
            true_y, cm_reg.predict(all_X)
        )
    )
    #### a_df processing here ################################################
    a_df = sim_df.loc[sim_df['activated'] == True, relevant_cols]
    a_y = a_df['after_activation_alters']
    a_X = a_df[['constant', 'var1']]
    a_reg = linear_model.LinearRegression(fit_intercept=False)
    a_reg.fit(a_X, a_y)
    # in-sample r-squared
    a_r2 = a_reg.score(a_X, a_y)
    # use model to predict for all
    a_rmse = sqrt(
        mean_squared_error(
            true_y, a_reg.predict(all_X)
        )
    )
    #### all processing here #################################################
    s_y = sim_df['threshold']
    s_X = sim_df[['constant', 'var1']]
    s_reg = linear_model.LinearRegression(fit_intercept=False)
    s_reg.fit(s_X, s_y)
    # in-sample r-squared
    s_r2 = s_reg.score(s_X, s_y)
    # use model to predict for all
    s_rmse = sqrt(
        mean_squared_error(
            true_y, s_reg.predict(all_X)
        )
    )
    #### naive rmse ##########################################################
    cm_naive_rmse = sqrt(
        mean_squared_error(
            cm_df['threshold'],
            cm_df['after_activation_alters'],
        )
    )
    a_naive_rmse = sqrt(
        mean_squared_error(
            a_df['threshold'],
            a_df['after_activation_alters'],
        )
    )
    #### make rmse_dict ######################################################
    rmse_dict['cm_num'] = cm_df.shape[0]
    rmse_dict['cm_epsilon_mean'] = cm_df['epsilon'].mean()
    rmse_dict['cm_cons_ols'] = cm_reg.coef_[0]
    rmse_dict['cm_beta_ols'] = cm_reg.coef_[1]
    rmse_dict['cm_r2'] = cm_r2
    rmse_dict['cm_rmse'] = cm_rmse
    rmse_dict['cm_naive_rmse'] = cm_naive_rmse
    rmse_dict['active_num'] = a_df.shape[0]
    rmse_dict['active_epsilon_mean'] = a_df['epsilon'].mean()
    rmse_dict['active_cons'] = a_reg.coef_[0]
    rmse_dict['active_beta'] = a_reg.coef_[1]
    rmse_dict['active_r2'] = a_r2
    rmse_dict['active_rmse'] = a_rmse
    rmse_dict['active_naive_rmse'] = a_naive_rmse
    rmse_dict['all_num'] = sim_df.shape[0]
    rmse_dict['true_epsilon_mean'] = sim_df['epsilon'].mean()
    rmse_dict['true_cons'] = s_reg.coef_[0]
    rmse_dict['true_beta'] = s_reg.coef_[1]
    rmse_dict['true_r2'] = s_r2
    rmse_dict['true_rmse'] = s_rmse
    return rmse_dict

def process_k(sim_df):
    """
    This function does the at-k obs stuff
    The goal here is simple:
        Take first 20, 30, 40, etc obs
        Predict for everyone
        Calc RMSE
    Record a couple of extra things:
        Naive RMSE (threshold - after_activation_alters)
        Correct RMSE (threshold ~ var1)
    """
    run_k_list = []
    sim_df['constant'] = 1
    true_y = sim_df['threshold']
    all_X = sim_df[['constant', 'var1']]
    relevant_cols = [
        'after_activation_alters',
        'constant',
        'var1',
        'activation_order',
    ]
    #### compute simulation-wide measures up front ###########################
    naive_rmse = sqrt(
        mean_squared_error(
            sim_df.loc[sim_df['activated'] == True, 'threshold'],
            sim_df.loc[sim_df['activated'] == True, 'after_activation_alters']
        )
    )
    s_reg = linear_model.LinearRegression()
    s_reg.fit(all_X, true_y)
    true_rmse = sqrt(
        mean_squared_error(
            true_y,
            s_reg.predict(all_X)
        )
    )
    #### make cm_df ##########################################################
    cm_df = sim_df.loc[sim_df['observed'] == 1, relevant_cols]
    cm_df.sort_values(
        by='activation_order',
        ascending=True,
        inplace=True
    )
    num_cm = cm_df.shape[0]
    k_iter = range(20, num_cm + 1, 10) # make iterator
    #### iterate through k ###################################################
    for k in k_iter:
        k_dict = {}
        k_df = cm_df.head(n=k)
        k_reg = linear_model.LinearRegression()
        k_reg.fit(k_df[['constant', 'var1']], k_df['after_activation_alters'])
        rmse_at_k = sqrt(
            mean_squared_error(
                true_y, k_reg.predict(all_X)
            )
        )
        k_dict['k'] = k
        k_dict['rmse_at_k'] = rmse_at_k
        k_dict['naive_rmse'] = naive_rmse
        k_dict['true_rmse'] = true_rmse
        run_k_list.append(k_dict)
    return run_k_list

def process_run(sim_run_path, sim_run_fname):
    """
    processes one run of sim, just saves us from opening the file twice
    """
    sim_param_dict = params_from_fname(sim_run_fname) # parse params
    sim_df = pd.read_csv(sim_run_path + sim_run_fname) # read file
    rmse_dict = process_rmse(sim_df)
    run_k_list = process_k(sim_df)
    # add params, gives an identifier
    rmse_dict.update(sim_param_dict)
    # dict.update is in-place
    for k_dict in run_k_list:
        k_dict.update(sim_param_dict)
    return rmse_dict, run_k_list

def process_runs(sim_run_path):
    """
    Goes through batches in an organized way
    Returns two dfs with the data we need
    This is a little different from the original R file:
        We don't do the aggregation within runs here
        We have one line per sim run, not one line per batch
    """
    rmse_list = []
    k_list = []
    for sim_run_fname in sim_run_fnames_iter(sim_run_path):
        rmse_dict, run_k_list = process_run(sim_run_path, sim_run_fname)
        rmse_list.append(rmse_dict)
        k_list.extend(run_k_list)
    rmse_df = pd.DataFrame.from_dict(rmse_list)
    k_df = pd.DataFrame.from_dict(k_list)
    return rmse_df, k_df

if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1].lower() == 'test':
        EMPIRICAL = False
        test_rmse_df, test_k_df = process_runs(TEST_PATH)
        test_rmse_df.to_csv(TEST_RMSE_DF_PATH)
        test_k_df.to_csv(TEST_K_DF_PATH)
    else:
        EMPIRICAL = False
        #sim_rmse_df, sim_k_df = process_runs(SIM_PATH)
        #sim_rmse_df.to_csv(SIM_RMSE_DF_PATH)
        #sim_k_df.to_csv(SIM_K_DF_PATH)
        EMPIRICAL = True
        empirical_rmse_df, empirical_k_df = process_runs(EMPIRICAL_PATH)
        empirical_rmse_df.to_csv(EMPIRICAL_RMSE_DF_PATH)
        empirical_k_df.to_csv(EMPIRICAL_K_DF_PATH)
