"""
This takes simulation runs and makes two output files

rmse_df:
df_k


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
    Yields one run of the simulation
    """
    with open(SIM_PATH, 'r') as f:
        dict_reader = csv.DictReader(f)
        for k, v in itertools.groupby(dict_reader, lambda x: x['rand_string']):
            df_sim = pd.DataFrame(list(v), dtype=float)
            params = get_sim_params(df_sim)
            yield df_sim, params

def get_sim_params(df_sim):
    sim_param_cols = [
        'cluster_prob',
        'constant',
        'epsilon_dist_mean',
        'epsilon_dist_sd',
        'graph_size',
        'graph_type',
        'mean_deg',
        'rewire_prob',
        'var1_dist_mean',
        'var1_dist_sd',
    ]
    return df_sim.loc[1, sim_param_cols].to_dict()

def process_rmse(df_sim, var_list=['var1'], sim_params=None):
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
    """
    all_vars = ['constant'] + var_list

    df_sim['constant'] = 1
    X_all = df_sim[all_vars]
    y_all_true = df_sim['threshold']
    # these are cols we keep when chopping up df_sim
    relevant_cols = [
        'threshold',
        'after_activation_alters',
        *all_vars,
        'epsilon',
    ]

    def calc_rmse_r2(X_subset, y_subset, X_all, y_all_true):
        ols = linear_model.LinearRegression(fit_intercept=False)
        ols.fit(X_subset, y_subset)
        # in-sample r-squared
        r2 = ols.score(X_subset, y_subset)
        # use this model to predict for all
        rmse = sqrt(
            mean_squared_error(
                y_all_true, ols.predict(X_all)
            )
        )
        return r2, rmse, ols

    #### correctly measured processing here ##################################
    df_measured = df_sim.loc[df_sim['observed'] == 1, relevant_cols]
    X_measured = df_measured[all_vars]
    y_measured = df_measured['after_activation_alters']
    r2_measured, rmse_measured, ols_measured = calc_rmse_r2(
        X_measured,
        y_measured,
        X_all,
        y_all_true,
    )

    #### actived processing here #############################################
    df_activated = df_sim.loc[df_sim['activated'] == 1, relevant_cols]
    y_activated = df_activated['after_activation_alters']
    X_activated = df_activated[all_vars]
    r2_activated, rmse_activated, ols_activated = calc_rmse_r2(
        X_activated,
        y_activated,
        X_all,
        y_all_true,
    )
    #### all processing here #################################################
    r2_all, rmse_all, ols_all = calc_rmse_r2(
        X_all,
        y_all_true,
        X_all,
        y_all_true,
    )

    #### naive rmse ##########################################################
    # use the exposure-at-activation-time rule
    # RMSE for everyone in the set
    rmse_activated_naive = sqrt(
        mean_squared_error(
            df_activated['threshold'],
            df_activated['after_activation_alters'],
        )
    )

    #### make rmse_dict ######################################################
    rmse_dict = {}

    rmse_dict['num_measured'] = df_measured.shape[0]
    rmse_dict['epsilon_mean_measured'] = df_measured['epsilon'].mean()
    rmse_dict['cons_measured_ols'] = ols_measured.coef_[0]
    rmse_dict['beta_measured_ols'] = ols_measured.coef_[1]
    rmse_dict['r2_measured_ols'] = r2_measured
    rmse_dict['rmse_measured_ols'] = rmse_measured

    rmse_dict['num_activated'] = df_activated.shape[0]
    rmse_dict['epsilon_mean_activated'] = df_activated['epsilon'].mean()
    rmse_dict['cons_activated_ols'] = ols_activated.coef_[0]
    rmse_dict['beta_activated_ols'] = ols_activated.coef_[1]
    rmse_dict['r2_activated_ols'] = r2_activated
    rmse_dict['rmse_activated_ols'] = rmse_activated
    rmse_dict['rmse_activated_naive'] = rmse_activated_naive

    rmse_dict['num_all'] = df_sim.shape[0]
    rmse_dict['epislon_mean_true'] = df_sim['epsilon'].mean()
    rmse_dict['cons_true'] = ols_all.coef_[0]
    rmse_dict['beta_true'] = ols_all.coef_[1]
    rmse_dict['r2_true'] = r2_all
    rmse_dict['rmse_true'] = rmse_all

    #add back sim params
    assert len(set(sim_params.keys()) & rmse_dict.keys()) == 0
    rmse_dict.update(sim_params)

    return rmse_dict

def process_k(df_sim, var_list=['var1'], sim_params=None):
    """
    This function does the at-k obs stuff
    The goal here is simple:
        Take first 20, 30, 40, etc obs
        Predict for everyone, calc RMSE
    Record a couple of extra things:
        Naive RMSE (threshold - after_activation_alters)
        Correct RMSE (threshold ~ var1)
    """
    df_sim['constant'] = 1
    all_vars = ['constant'] + var_list

    true_y = df_sim['threshold']
    all_X = df_sim[all_vars]
    relevant_cols = [
        'after_activation_alters',
        *all_vars,
        'activation_order',
    ]

    #### compute simulation-wide measures up front ###########################
    rmse_naive = sqrt(
        mean_squared_error(
            df_sim.loc[df_sim['activated'] == 1, 'threshold'],
            df_sim.loc[df_sim['activated'] == 1, 'after_activation_alters'],
        )
    )
    ols_all = linear_model.LinearRegression()
    ols_all.fit(all_X, true_y)
    rmse_true = sqrt(
        mean_squared_error(
            true_y,
            ols_all.predict(all_X)
        )
    )

    #### make df_measured ####################################################
    df_measured = df_sim.loc[df_sim['observed'] == 1, relevant_cols]
    df_measured.sort_values(
        by='activation_order',
        ascending=True,
        inplace=True,
    )
    num_measured = df_measured.shape[0]

    #### iterate through k ###################################################
    run_k_list = []
    k_iter = range(20, num_measured + 1, 10) # make iterator
    for k in k_iter:
        k_dict = {}
        df_k = df_measured.head(n=k)
        X_k = df_k[all_vars]
        y_k = df_k['after_activation_alters']
        ols_k = linear_model.LinearRegression()
        ols_k.fit(df_k[all_vars], y_k)
        rmse_at_k = sqrt(
            mean_squared_error(
                true_y, ols_k.predict(all_X)
            )
        )
        k_dict['k'] = k
        k_dict['rmse_at_k'] = rmse_at_k
        k_dict['rmse_naive'] = rmse_naive
        k_dict['rmse_true'] = rmse_true
        # add back sim params
        assert len(set(sim_params.keys()) & k_dict.keys()) == 0
        k_dict.update(sim_params)
        run_k_list.append(k_dict)
    return run_k_list

def bail_out(df_sim):
    if sum(df_sim['activated'] == 1) < 1:
        print('bailed out')
        return True
    return False

if __name__ == '__main__':
    rmse_records = []
    k_records = []
    counter = 0

    for df_sim, sim_params in yield_sim_records(SIM_PATH):
        if bail_out(df_sim):
            counter += 1
            continue
        rmse_dict = process_rmse(df_sim, sim_params=sim_params)
        k_list = process_k(df_sim, sim_params=sim_params)

        rmse_records.append(rmse_dict)
        k_records.extend(k_list)
        counter += 1

        if counter % 1000 == 0:
            print('Processed {} runs!'.format(counter))

        if sys.argv[1].lower() == 'test':
            print(rmse_dict)
            print(k_list)
            break

    df_rmse = pd.DataFrame(rmse_records)
    df_rmse.to_csv(SIM_RMSE_DF_PATH)
    df_k = pd.DataFrame(k_records)
    df_k.to_csv(SIM_K_DF_PATH)
