import networkx as nx
import pandas as pd
import random
from time import time
from functools import wraps
import re
import numpy as np
import math
import json
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
    - What about using skewness to adjust for normality
        i.e. we can guess which way the error is biased based on 3rd moment
    - Make point that this affects probabalistic models as well
    - Use network-level measures as proxies for selection
    - Select nodes that have absence of collisions only!
    - Quantify bias in distribution
"""

def timer(f):
    @wraps(f)
    def wrapper(*args,**kwargs):
        tic = time()
        print("Starting " + f.__name__)
        result = f(*args, **kwargs)
        print(f.__name__ + " took " + str(time() - tic) + " seconds")
        return result
    return wrapper

## Threshold creation functions ##

'''
We want to systematically and easily be able to generate thresholds drawn from various combinations of independent distributions

The two important distributions for our purposes are the N(0,1) and the Binomial(1, .5), or the normal with mean 0 and sd 1, and the binomial with 1 flip and .5 chance of heads.

We want to be able to easily describe a threshold equation in terms of arbitrary linear combinations of the normal and binomial

NEW FANCY SYNTAX:
equation = {
    'var_1_name': {
        'distribution': 'normal',
        'mean': mean,
        'sd': sd,
        'coefficient': coefficient
    },
    'var_2_name': {
        ...
    },
    ...
}
'''

def create_thresholds(n, equation):
    '''
    equation looks like:
    {'var 1': {info}}

    n: Number of samples to draw
    equation: R style regression equation
    distribution_dict: dict of form {'var_name': 'normal'}
        accepts 'normal' or 'binomial'

    outputs list of dicts of form:
        {'threshold': y, 'age': val, 'gender': val, ...}
    '''
    output_list_of_dicts = []

    for node in range(n):
        node_variable_dict = {}
        threshold_total = 0.0
        for var_name, var_info in equation.items():
            mean = var_info.get('mean')
            sd = var_info.get('sd')
            coefficient = var_info.get('coefficient')
            if var_name == 'constant':
                threshold_total += mean
                node_variable_dict[var_name] = mean
            elif var_name == 'epsilon':
                draw = np.random.normal(mean, sd)
                node_variable_dict[var_name] = draw
                threshold_total += draw
            else:
                draw = np.random.normal(mean, sd)
                node_variable_dict[var_name] = draw
                threshold_total += coefficient * draw
        node_variable_dict['threshold'] = threshold_total
        output_list_of_dicts.append(node_variable_dict)
    return output_list_of_dicts

## Simulation functions ##

@timer
def label_graph_with_thresholds(graph, thresh_and_cov):
    '''
    Assigns thresholds to nodes in graph

    thresh_and_cov should be in form:
        [{'threshold': val, 'cov 1': val, 'cov 2': val}, ...]

    If there are no covariates, we'll just have an empty dict as covariates

    Don't be stupid and make covariate names "threshold"

    Also, we label nodes here with network-level information
        evcent
        closeness
        betweenness
        pagerank
    '''
    degree = nx.degree_centrality(graph)
    # closeness = nx.closeness_centrality(graph)
    # betweenness = nx.betweenness_centrality(graph)
    # pagerank = nx.pagerank_scipy(graph)
    # evcent = nx.eigenvector_centrality(graph)

    idx = 0

    assert graph.number_of_nodes() == len(thresh_and_cov)
    for name, node_attrs in graph.nodes_iter(data=True):
        node_thresh_cov = thresh_and_cov[idx]
        idx += 1
        node_attrs['activated'] = False
        node_attrs['before_activation_alters'] = None
        node_attrs['after_activation_alters'] = None
        for cov_name, val in node_thresh_cov.items():
            node_attrs[cov_name] = val
        node_attrs['degree'] = degree[name]
        # node_attrs['closeness'] = closeness[idx]
        # node_attrs['betweenness'] = betweenness[idx]
        # node_attrs['pagerank'] = pagerank[idx]
        # node_attrs['evcent'] = evcent[idx]
    return graph

@timer
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
    activation_order = 1

    while len(unactivated_node_set) > 0:
        num_steps += 1
        ego = random.sample(unactivated_node_set, 1)[0]
        alter_set = set(g[ego].keys())
        activated_alters_num = len(alter_set & activated_node_set)
        threshold = g.node[ego]['threshold']
        if activated_alters_num >= threshold:
            # record empirical number of neighbors at activation time
            g.node[ego]['after_activation_alters'] = activated_alters_num
            g.node[ego]['activation_order'] = activation_order
            activation_order += 1
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
    def subtract_or_none(x, y):
        if x != None and y != None:
            return x - y
        else:
            return None
    g = graph_after_simulation
    data_list_of_dicts = []
    for node, data in g.nodes_iter(data=True):
        data['name'] = node
        activated = data['activated']
        after_activation_alters = data['after_activation_alters']
        before_activation_alters = data['before_activation_alters']
        difference = subtract_or_none(
            after_activation_alters,
            before_activation_alters,
        )
        if after_activation_alters == 0:
            print('observed 1', after_activation_alters, before_activation_alters)
            data['observed'] = 1
        elif difference == 1:
            print('observed 2', after_activation_alters, before_activation_alters)
            data['observed'] = 1
        else:
            print('unobserved', after_activation_alters, before_activation_alters)
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
        evcent
        closeness
        betweenness
        pagerank
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
    output_path,
    graph,
    threshold_equation,
    ):
    """
    One run of the sim
    """
    n = graph.number_of_nodes()
    thresh_and_cov = create_thresholds(
        n,
        threshold_equation
    )
    labeled_graph = label_graph_with_thresholds(
        graph,
        thresh_and_cov,
    )
    simulated_graph = async_simulation(labeled_graph)
    df = make_dataframe_from_simulation(simulated_graph)
    df.to_csv(output_path)

def sim_reps(
    n_rep,
    output_hash,
    *sim_params,
    ):
    for sim_num in range(n_rep):
        output_path = 'sim_' + output_hash + '_' + str(sim_num)
        run_sim(output_folder, *sim_params)

if __name__ == '__main__':
    # some relatively constant definitions
    output_folder = '/Users/g/Google Drive/project-thresholds/thresholds/data/'
    threshold_eq_param_space_file = '../../data/made_up_param_space.json'
    threshold_eq_param_space = []
    with open(threshold_eq_param_space_file, 'rb') as f:
        for line in f:
            j = json.loads(line)
            threshold_eq_param_space.append(j)
    mean_degrees = [5, 10, 15, 20, 25]
    graph_sizes = [1000, 5000, 10000]

    # watts strogatz graph
    p = 0.2
    ws_output_path = output_folder + 'ws_output.csv'
    ws_graph = nx.watts_strogatz_graph(n, d, p)
    ws_df = run_sim(ws_graph, threshold_eq, ws_output_path)

    gexf_ws_output = output_folder + 'ws_output.gexf'
    #nx.write_gexf(ws_graph, gexf_ws_output)

    # regular random graph
    rg_output_path = output_folder + 'rg_output.csv'
    rg_graph = nx.random_regular_graph(d, n)
    rg_df = run_sim(rg_graph, threshold_eq, rg_output_path)
    gexf_rg_output = output_folder + 'rg_output.gexf'
    #nx.write_gexf(rg_graph, gexf_rg_output)

    # power law graph
    m = 4
    pl_output_path = output_folder + 'pl_output.csv'
    pl_graph = nx.barabasi_albert_graph(n, m)
    pl_df = run_sim(pl_graph, threshold_eq, pl_output_path)
    gexf_pl_output = output_folder + 'pl_output.gexf'
    #nx.write_gexf(pl_graph, gexf_pl_output)

    """
    threshold_eq = {
        'constant': {
            'distribution': 'constant',
            'mean': 5.0,
        },
        'var1': {
            'distribution': 'normal',
            'mean': 0.0,
            'sd': 1.5,
            'coefficient': 2.0,
        },
        'epsilon': {
            'distribution': 'normal',
            'mean': 0.0,
            'sd': 0.5,
        },
    }
    # real life graph
    real_graph_output = output_folder + 'real_output.csv'
    real_graph = nx.read_edgelist(
        output_folder + 'UCSC68_gc.ncol',
        nodetype=int,
    )
    real_df = run_sim(real_graph, threshold_eq, real_graph_output)
    gexf_real_output = output_folder + 'real_output.gexf'
    #nx.write_gexf(real_graph, gexf_real_output)


    # power law clustered graph
    p = 0.02
    pg_output_path = output_folder + 'pg_output.csv'
    pg_graph = nx.powerlaw_cluster_graph(n, m, p)
    pg_df = run_sim(pg_graph, threshold_eq, pg_output_path)

    # poisson random graph
    p = 0.05
    ps_output_path = output_folder + 'ps_output.csv'
    ps_graph = nx.gnp_random_graph(n, p)
    ps_df = run_sim(ps_graph, threshold_eq, ps_output_path)
    """
