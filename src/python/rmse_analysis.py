"""
This takes simulation runs and makes two output files

rmse_df:
k_df


activated,activation_order,after_activation_alters,before_activation_alters,constant,constant_dist_coef,constant_dist_mean,constant_dist_sd,degree,epsilon,epsilon_dist_coef,epsilon_dist_mean,epsilon_dist_sd,name,observed,rand_string,threshold,var1,var1_dist_coef,var1_dist_mean,var1_dist_sd

"""
import os
import csv
import sys
import itertools
import pandas as pd
from math import sqrt
from sklearn import linear_model
from sklearn.metrics import mean_squared_error
from constants import *

def yield_sim_records(path):
    """
    Yields elements grouped by rand_string
    """
    with open(SIM_PATH, 'r') as f:
        dict_reader = csv.DictReader(f)
        for k, v in itertools.groupby(dict_reader, lambda x: x['rand_string']):
            yield list(v)

def process_rmse(sim_records):
    """
    Performs RMSE analysis for one simulation run

    The records passed have something like these columns
        activated
        activation_order
        after_activation_alters
        before_activation_alters
        constant
        constant_dist_coef
        constant_dist_mean
        constant_dist_sd
        degree
        epsilon
        epsilon_dist_coef
        epsilon_dist_mean
        epsilon_dist_sd
        name
        observed
        rand_string
        threshold
        var1
        var1_dist_coef
        var1_dist_mean
        var1_dist_sd
        ...
        varN
        varN_dist_coef
        varN_dist_mean
        varN_dist_sd

    Note: there may be multiple variables at the end
    The rest of the columns are fixed




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
    all_df
    measured_df
    activated_df

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
    s_naive_rmse = sqrt(
        mean_squared_error(
            s_df['threshold'],
            s_df['after_activation_alters'],
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
    rmse_dict['naive_rmse'] = s_naive_rmse
    return rmse_dict

def process_k(sim_df):
    """
    This function does the at-k obs stuff
    The goal here is simple:
        Take first 20, 30, 40, etc obs
        Predict for everyone, calc RMSE
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
        inplace=True,
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

if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1].lower() == 'test':
        EMPIRICAL = False
        test_rmse_df, test_k_df = process_runs(TEST_PATH)
        test_rmse_df.to_csv(TEST_RMSE_DF_PATH)
        test_k_df.to_csv(TEST_K_DF_PATH)
    else:
        EMPIRICAL = False
        sim_rmse_df, sim_k_df = process_runs(SIM_PATH)
        sim_rmse_df.to_csv(SIM_RMSE_DF_PATH)
        sim_k_df.to_csv(SIM_K_DF_PATH)
        #EMPIRICAL = True
        #empirical_rmse_df, empirical_k_df = process_runs(EMPIRICAL_PATH)
        #empirical_rmse_df.to_csv(EMPIRICAL_RMSE_DF_PATH)
        #empirical_k_df.to_csv(EMPIRICAL_K_DF_PATH)
