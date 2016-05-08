import networkx as nx
import pandas as pd
import random
from time import time
from functools import wraps
import re
import numpy as np
import math
import json
import os

from constants import *
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

How to use lots of sim runs:
    We get a CSV file for each run that lets us do nice things
    We'd like to assess two things:
        1) Within-param variance (i.e. for graph with X nodes and Y threshold function, how much variance is there?)
        2) Across-param variance (i.e. are there some threshold distributions that are particularly problematic?)
    The problem is that we have a veritable fuck-ton of parameters
    What are the most important input params?
        Graph topology
        Size of error variance
    What are the most important output measures?
        RMSE curve

    OKAY, here are some instructive plots:
        Naive thresholds vs correct
        RMSE curve for graph X with cov dist Y as we vary error variance
            We can even avg within param vals
            The within-params analysis is necessary to assess differences

    Can we do half-half on only the observed thresholds to determine the best RMSE point?

    To do this analysis, we do NOT need an enormous parameter space

TODO:
    - What about using skewness to adjust for normality
        i.e. we can guess which way the error is biased based on 3rd moment
    - Make point that this affects probabalistic models as well
    - Use network-level measures as proxies for selection
    - Select nodes that have absence of collisions only!
    - Quantify bias in distribution
"""

## Functions ##

def timer(f):
    @wraps(f)
    def wrapper(*args,**kwargs):
        tic = time()
        print("Starting " + f.__name__)
        result = f(*args, **kwargs)
        print(f.__name__ + " took " + str(time() - tic) + " seconds")
        return result
    return wrapper

## Threshold creation ##

def create_thresholds(n, equation):
    '''
    intput looks like:
    n: Number of samples to draw
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
    output_list_of_dicts = []
    for node in range(n):
        node_variable_dict = {}
        threshold_total = 0.0
        for var_name, var_info in equation.items():
            mean = var_info['mean']
            sd = var_info['sd']
            coefficient = var_info['coefficient']
            if var_name == 'constant':
                threshold_total += coefficient
                node_variable_dict[var_name] = coefficient
            elif var_name == 'epsilon':
                draw = np.random.normal(0, sd)
                node_variable_dict[var_name] = draw
                threshold_total += draw
            else:
                draw = np.random.normal(0, sd)
                node_variable_dict[var_name] = draw
                threshold_total += coefficient * draw
        node_variable_dict['threshold'] = threshold_total
        output_list_of_dicts.append(node_variable_dict)
    return output_list_of_dicts

## Simulation functions ##

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
        node_attrs['activation_order'] = None
        for cov_name, val in node_thresh_cov.items():
            node_attrs[cov_name] = val
        node_attrs['degree'] = degree[name]
        # node_attrs['closeness'] = closeness[idx]
        # node_attrs['betweenness'] = betweenness[idx]
        # node_attrs['pagerank'] = pagerank[idx]
        # node_attrs['evcent'] = evcent[idx]
    return graph

def random_sequence(node_set):
    """
    Shuffle nodes without replacement
    Return them one at a time as an iterator
    """
    seq = np.random.choice(list(node_set), len(node_set), replace=False)
    for elem in seq:
        yield elem

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

    # activated_node_set = get_activated_node_set(g.node)
    activated_node_set = set()
    unactivated_node_set = all_node_set

    steps_without_activation = 0
    activation_order = 0
    rand_seq = random_sequence(unactivated_node_set)

    while len(unactivated_node_set) > 0:
        try:
            ego = next(rand_seq)
        except StopIteration:
            rand_seq = random_sequence(unactivated_node_set)
            ego = next(rand_seq)
        alter_set = set(g[ego].keys())
        activated_alters_num = len(alter_set & activated_node_set)
        threshold = g.node[ego]['threshold']
        if activated_alters_num >= threshold:
            # record empirical number of neighbors at activation time
            g.node[ego]['after_activation_alters'] = activated_alters_num
            activation_order += 1
            g.node[ego]['activation_order'] = activation_order
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
    return g

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
    for node, node_attrs in g.nodes_iter(data=True):
        node_attrs['name'] = node
        activated = node_attrs['activated']
        after_activation_alters = node_attrs['after_activation_alters']
        before_activation_alters = node_attrs['before_activation_alters']
        difference = subtract_or_none(
            after_activation_alters,
            before_activation_alters,
        )
        if after_activation_alters == 0:
            node_attrs['observed'] = 1
        elif difference == 1:
            node_attrs['observed'] = 1
        else:
            node_attrs['observed'] = 0
        data_list_of_dicts.append(node_attrs)
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
    print('Num activated {}; Num observed {}'.format(
        sum(df.activated),
        sum(df.observed)
    ))
    df.to_csv(output_path)

@timer
def sim_reps(
    n_rep,
    output_id,
    *sim_params
    ):
    for sim_num in range(n_rep):
        output_path = SIM_PATH + output_id + '~' + str(sim_num) + '.csv'
        run_sim(output_path, *sim_params)

def eq_to_str(eq_dict):
    """
    get leaves and turn them into params
    """
    var_order = ['distribution', 'coefficient', 'mean', 'sd']
    eq_list = []
    for vname, val_dict in eq_dict.items():
        var_list = []
        for var in var_order:
            val = val_dict[var]
            if val == None:
                var_list.append('N')
            elif val == 'constant':
                var_list.append('c')
            elif val == 'epsilon':
                var_list.append('e')
            elif val == 'normal':
                var_list.append('n')
            else:
                var_list.append(str(val))
        eq_list.append('_'.join(var_list))
    return '__'.join(eq_list)

def create_output_identifier(
    eq_dict,
    graph_params,
    ):
    """
    Simple type of serialization to describe the graph parameters

    Divide the threshold function and graph params by ___
    Divide variables within the threshold function by __
    Divide all other elements by _

    Can then split on ___, then __, then _
    """
    id_list = []
    eq_str = eq_to_str(eq_dict)
    id_list.append(eq_str)
    param_list = []
    for param in graph_params:
        if param == None:
            param_list.append('N')
        else:
            param_list.append(str(param))
    param_str = '_'.join(param_list)
    id_list.append(param_str)
    id_str = '___'.join(id_list)
    return id_str.replace('.', '-')

if __name__ == '__main__':
    ## Constants ##

    N_REPS = 1000

    # some relatively constant definitions
    threshold_eq_param_space = []
    with open(SIM_PARAM_FILE, 'rb') as f:
        for line in f:
            j = json.loads(line)
            threshold_eq_param_space.append(j)
    mean_degrees = [12, 16, 20]
    graph_sizes = [1000]
    ws_rewire_probs = [.1]
    pl_cluster_probs = [.1]

    # this is for purely sim graphs
    for eq in threshold_eq_param_space:
        for md in mean_degrees:
            for gs in graph_sizes:
                print("{} {} {}".format(eq, md, gs))
                # ws
                for p in ws_rewire_probs:
                    output_id = create_output_identifier(
                        eq,
                        [md, gs, 'ws', p],
                    )
                    ws_graph = nx.watts_strogatz_graph(gs, md, p)
                    sim_reps(N_REPS, output_id, ws_graph, eq)
                """
                # pl
                pl_graph = nx.barabasi_albert_graph(gs, int(md/2.))
                output_id = create_output_identifier(
                    eq,
                    md,
                    gs,
                    'pl',
                )
                sim_reps(N_REPS, output_id, pl_graph, eq)
                """
                # pl w/ clustering
                for c in pl_cluster_probs:
                    output_id = create_output_identifier(
                        eq,
                        [md, gs, 'plc', p],
                    )
                    plc_graph = nx.powerlaw_cluster_graph(gs, int(md/2.), c)
                    sim_reps(N_REPS, output_id, plc_graph, eq)