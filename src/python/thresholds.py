import networkx as nx
import pandas as pd
import random
from time import time
from functools import wraps
import re
import numpy as np
import math
"""
This file allows us to:
    1. Create random graphs with certain properties using NetworkX
    2. Label graph topology with draws from a threshold distribution
    3. Run an async-update contagion process
    4. Store exposure-adoption information for each node in the simulation
    5. Output relevant information to a nice CSV for analysis

The label-simulate functions should take a NetworkX graph as input
This will allow us to easily use empirical topologies (just read them into nx)

We use networkx and store relevant node-attributes on the graph.node dict
    graph.node[node] looks like this:
        {
            'threshold': float,
            'activated': bool,
            'covariates': {'cov name': cov_val}
        }

TODO:
    Do we record 0 threshold people correctly?
"""

def timer(f):
    @wraps(f)
    def wrapper(*args,**kwargs):
        tic = time()
        result = f(*args, **kwargs)
        print(f.__name__ + " took " + str(time() - tic) + " seconds")
        return result
    return wrapper

## Threshold creation functions ##

'''
We want to systematically and easily be able to generate thresholds drawn from various combinations of independent distributions

The two important distributions for our purposes are the N(0,1) and the Binomial(1, .5), or the normal with mean 0 and variance 1, and the binomial with 1 flip and .5 chance of heads.

We want to be able to easily describe a threshold equation in terms of arbitrary linear combinations of the normal and binomial

Use R syntax:
    y ~ 3 * age + 2 * gender - 1 * motivation + epsilon
'''

def create_thresholds(n, equation, distribution_dict):
    '''
    n: Number of samples to draw
    equation: R style regression equation
    distribution_dict: dict of form {'var_name': 'normal'}
        accepts 'normal' or 'binomial'

    outputs list of dicts of form:
        {'threshold': y, 'age': val, 'gender': val, ...}
    '''
    output_list_of_dicts = []
    iv_tuples = parse_equation(equation)

    for node in range(n):
        node_dict = {}
        epsilon = np.random.normal(0, 1)
        threshold_calc_list = [epsilon]
        for iv_info in iv_tuples:
            coefficient, var_name = float(iv_info[0]), iv_info[1]
            if var_name == 'constant':
                threshold_calc_list.append(coefficient)
            else:
                distribution_str = distribution_dict[var_name]
                draw = random_draw_from_correct_distribution(distribution_str)
                node_dict[var_name] = draw
                threshold_calc_list.append(coefficient * draw)
        threshold = sum(threshold_calc_list)
        node_dict['threshold'] = threshold
        output_list_of_dicts.append(node_dict)
    return output_list_of_dicts

def parse_equation(eq_str):
    '''
    String parse this:
    1) split on tilde
    2) split on +/-
    3) look for epsilon, and assign it N(0, 1)
    4) split on *
    5) match variable names to dictionary of either 'normal' or 'binomial'
    6) create {'threshold': y, 'age': val, 'gender': val, ...}
    '''
    tilde_pattern = r' *~ *'
    plus_minus_pattern = r' *[\+|\-] *'
    star_pattern = r' *\* *'

    # input: 'y ~ 5 + 3 * age + 2 * gender - 1 * motivation

    # iv_str: '5 + 3 * age + 2 * gender - 1 * motivation'
    dv_str, iv_str = re.split(tilde_pattern, eq_str)

    # iv_list: ['5', '3 * age', '2 * gender', '1 * motivation']
    iv_list = re.split(plus_minus_pattern, iv_str)
    constant = iv_list.pop(0)

    # iv_tuples: [('3', 'age'), ('2', 'gender'), ('1', 'motivation')]
    iv_tuples = [
        tuple(re.split(star_pattern, x)) for x in iv_list
    ]
    iv_tuples.append((constant, 'constant'))
    return iv_tuples

def random_draw_from_correct_distribution(distribution_str):
    if distribution_str.lower() == 'normal':
        return np.random.normal(0, 1)
    if distribution_str.lower() == 'binomial':
        return np.random.binomial(1, .5)

## Simulation functions ##

def label_graph_with_thresholds(graph, thresh_and_cov):
    '''
    Assigns thresholds to nodes in graph

    thresh_and_cov should be in form:
        [{'threshold': val, 'cov 1': val, 'cov 2': val}, ...]

    If there are no covariates, we'll just have an empty dict as covariates

    Don't be stupid and make covariate names "threshold"
    '''

    assert len(graph.node) == len(thresh_and_cov)
    for idx, ego in enumerate(graph.nodes_iter()):
        node_thresh_cov = thresh_and_cov[idx]
        threshold = node_thresh_cov.pop('threshold')
        covariates = node_thresh_cov
        graph.node[ego]['threshold'] = threshold
        graph.node[ego]['activated'] = False
        graph.node[ego]['before_activation_alters'] = 0
        graph.node[ego]['after_activation_alters'] = 0
        graph.node[ego]['degree'] = graph.degree(idx)
        for cov_name, cov_val in covariates.items():
            graph.node[ego][cov_name] = cov_val
    return graph

def async_simulation(graph_with_thresholds):
    '''
    Give this the graph with thresholds

    Async update procedure:
        Get a set of all unactivated nodes
        Sample from this, updating as we go along
            Until we haven't seen an update in a long time
        We record each time we visit a node
            If the node is not active, we record the visit on 'before_activation', overrwriting previous visits
            If the node is activated, we reocord on 'after_activation'
            Max 2 obs for each node

        Visit information is stored in format:
            Just need node id, and number of active neighbors

    Everything is stored in node attributes on the graph
    '''
    g = graph_with_thresholds
    all_node_set = set(g.nodes_iter())
    num_nodes = len(all_node_set)

    activated_node_set = get_activated_node_set(g.node)
    unactivated_node_set = all_node_set - activated_node_set

    steps_without_activation = 0
    num_steps = 0

    while len(unactivated_node_set) > 0:
        num_steps += 1
        ego = random.sample(unactivated_node_set, 1)[0]
        alter_set = set(g[ego].keys())
        activated_alters_num = len(alter_set & activated_node_set)
        threshold = g.node[ego]['threshold']
        if activated_alters_num >= threshold:
            # record empirical number of neighbors at activation time
            g.node[ego]['after_activation_alters'] = activated_alters_num
            # record activation status on graph
            g.node[ego]['activated'] = True
            activated_node_set.add(ego)
            unactivated_node_set.remove(ego)
            steps_without_activation = 0
        else:
            g.node[ego]['before_activation_alters'] = activated_alters_num
            steps_without_activation += 1
            if steps_without_activation > num_nodes:
                break
    print('num steps: {}, num unactivated: {}'.format(num_steps, len(unactivated_node_set)))
    return g

def get_activated_node_set(node_dicts):
    activated_set = set()
    for node, data in node_dicts.items():
        if data['activated'] == True:
            activated_set.add(node)
    return activated_set

def make_dataframe_from_simulation(graph_after_simulation):
    '''
    We give this the graph resulting from the simulation

    Graph stores node data like this:
        {
            'threshold': float,
            'activated': bool,
            'cov1': val,
            'cov2': val,
            ...,
            'before_activation_alters': int
            'after_activation_alters': int
            'degree': int
        }

    We use this to make a pandas dataframe
    One row per node

    We have a bunch of standard col names, plus the cov names
        covs can be 0, 1, 2, etc cols

    '''
    g = graph_after_simulation

    data_list_of_dicts = []

    for node, data in g.nodes_iter(data=True):
        data['name'] = node
        after_activation_alters = data['after_activation_alters']
        before_activation_alters = data['before_activation_alters']
        if after_activation_alters == 0:
            data['observed'] = 1
        elif after_activation_alters - before_activation_alters == 1:
            data['observed'] = 1
        else:
            data['observed'] = 0
        data_list_of_dicts.append(data)

    df = pd.DataFrame(data_list_of_dicts)
    df = df.set_index('name')
    df.activated = df.activated.astype(int)
    new_df_colnames = get_column_ordering(df.columns.tolist())
    df = df.reindex_axis(new_df_colnames, axis=1)

    return df

def get_column_ordering(df_colnames):
    '''
    We have some hardcoded categories that we always want at the front

    The covariate names should always be at the end in some arbitrary order

    The stuff we always have is:
        name (excluded because it's the index)
        activated
        threshold
        before_activation_alters
        after_activation_alters
        degree
        observed
    '''
    new_df_colnames = [
        'activated',
        'threshold',
        'before_activation_alters',
        'after_activation_alters',
        'degree',
        'observed',
    ]
    covariate_list = list(set(df_colnames) - set(new_df_colnames))
    new_df_colnames.extend(covariate_list)
    return new_df_colnames

@timer
def run_sim(
    graph,
    threshold_eqation,
    distribution_dict,
    output_path,
    ):

    n = graph.number_of_nodes()
    thresh_and_cov = create_thresholds(
        n,
        threshold_eq,
        distribution_dict
    )
    labeled_graph = label_graph_with_thresholds(
        graph,
        thresh_and_cov,
    )
    simulated_graph = async_simulation(labeled_graph)
    df = make_dataframe_from_simulation(simulated_graph)
    df.to_csv(output_path)


if __name__ == '__main__':
    # some relatively constant definitions
    output_folder = '/Users/g/Google Drive/project-thresholds/thresholds/data/'
    threshold_eq = 'y ~ 3 + 1 * age'
    distribution_dict = {
        'age': 'normal',
    }
    d = 10
    n = 10000

    # watts strogatz graph
    p = 0.2
    ws_output_path = output_folder + 'ws_output.csv'
    ws_graph = nx.watts_strogatz_graph(n, d, p)
    ws_df = run_sim(ws_graph, threshold_eq, distribution_dict, ws_output_path)

    '''
    # regular random graph
    rg_output_path = output_folder + 'rg_output.csv'
    rg_graph = nx.random_regular_graph(d, n)
    rg_df = run_sim(rg_graph, threshold_eq, distribution_dict, rg_output_path)

    # power law graph
    m = 4
    pl_output_path = output_folder + 'pl_output.csv'
    pl_graph = nx.barabasi_albert_graph(n, m)
    pl_df = run_sim(pl_graph, threshold_eq, distribution_dict, pl_output_path)

    # power law clustered graph
    p = 0.02
    pg_output_path = output_folder + 'pg_output.csv'
    pg_graph = nx.powerlaw_cluster_graph(n, m, p)
    pg_df = run_sim(pg_graph, threshold_eq, distribution_dict, pg_output_path)

    # poisson random graph
    p = 0.05
    ps_output_path = output_folder + 'ps_output.csv'
    ps_graph = nx.gnp_random_graph(n, p)
    ps_df = run_sim(ps_graph, threshold_eq, distribution_dict, ps_output_path)
    '''
