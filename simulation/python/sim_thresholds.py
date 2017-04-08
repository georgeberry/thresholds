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
import csv

from constants import *
"""
Overview
~~~~~~~

This file:
    1. Creates random graphs with certain properties using NetworkX
    2. Labels graph topology with draws from a threshold distribution
    3. Runs an async-update contagion process
    4. Stores exposure-adoption information for each node in the simulation
    5. Outputs relevant information to a nice CSV for analysis


Philosophy
~~~~~~~~~~

The label-simulate functions should take a NetworkX graph as input
This will allow us to easily use any topology in NX form

We use NetworkX and store relevant node-attributes on the graph.node dict
    graph.node[node] looks like this:
        {
            'threshold': float,
            'activated': bool,
            'covariates': {'cov name': cov_val}
        }

What are the most important input params?
    Graph topology
    Size of error variance

What are the most important output measures?
    RMSE curve

Scale
~~~~~

Outputs CSV file for each run
Encode parameters in the filename

Use the rmse_analysis.py file on the sim runs


TODO / Ideas
~~~~~~~~~~~~

    - What about using skewness to adjust for normality
        i.e. we can guess which way the error is biased based on 3rd moment
    - Make point that this affects probabalistic models as well
    - Quantify bias in distribution
    -
"""

CHARS = '0123456789abcdefghijklmnopqrstufvwxyz'

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

#### Threshold draws ########################################################

def create_thresholds(n, equation):
    """
    inputs:
        n: Number of samples to draw
        equation: {
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
    outputs:
        [
            {'var_name': value, 'threshold': value, ...}
        ]

    """
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

#### Graph setup functions ##################################################

def label_graph_with_thresholds(graph, thresh_and_cov, network_stats=False):
    """
    Assigns thresholds to nodes in graph

    Inputs:
        graph: NetworkX graph
        thresh_and_cov: [{'threshold': val, 'cov 1': val, 'cov 2': val}, ...]

    Note: Don't be stupid and make covariate names "threshold"

    Outputs:
        graph: nodes randomly labeled with elements of thresh_and_cov

    If network_stats=True, label nodes here with network-level information
        evcent
        closeness
        betweenness
        pagerank
    """
    assert graph.number_of_nodes() == len(thresh_and_cov)

    degree = nx.degree_centrality(graph)
    if network_stats == True:
        closeness = nx.closeness_centrality(graph)
        betweenness = nx.betweenness_centrality(graph)
        pagerank = nx.pagerank_scipy(graph)
        evcent = nx.eigenvector_centrality(graph)

    idx = 0
    for name, node_attrs in graph.nodes_iter(data=True):
        node_thresh_cov = thresh_and_cov[idx]
        idx += 1
        node_attrs['activated'] = 0
        node_attrs['before_activation_alters'] = None
        node_attrs['after_activation_alters'] = None
        node_attrs['activation_order'] = None
        for cov_name, val in node_thresh_cov.items():
            node_attrs[cov_name] = val
        node_attrs['degree'] = degree[name]
        if network_stats == True:
            node_attrs['closeness'] = closeness[idx]
            node_attrs['betweenness'] = betweenness[idx]
            node_attrs['pagerank'] = pagerank[idx]
            node_attrs['evcent'] = evcent[idx]
    return graph

def yield_random_nodes(node_set):
    """
    Inputs:
        node_set: an iterable containing nodes
    Outputs:
        Yields randomly shuffled nodes one at a time
    Shuffle nodes without replacement

    Assumption of without replacement should make little practical difference
        It ensures our stop condition is correct
    """
    seq = np.random.choice(list(node_set), len(node_set), replace=False)
    for elem in seq:
        yield elem

#### Simulation functions ###################################################

def async_simulation(graph_with_thresholds):
    """
    Input:
        A graph with thresholds as node attributes

    Outputs:
        A graph with additional information on the nodes
        Indicating the result of the simulation

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
    """
    g = graph_with_thresholds
    all_node_set = set(g.nodes_iter())
    num_nodes = len(all_node_set)

    # activated_node_set = get_activated_node_set(g.node)
    activated_node_set = set()
    unactivated_node_set = all_node_set

    steps_without_activation = 0
    activation_order = 0
    node_rand_seq = yield_random_nodes(unactivated_node_set)

    while len(unactivated_node_set) > 0:
        try:
            ego = next(node_rand_seq)
        except StopIteration:
            node_rand_seq = yield_random_nodes(unactivated_node_set)
            ego = next(node_rand_seq)
        # if person has activated, we skip them
        if ego in activated_node_set:
            continue
        alter_set = set(g[ego].keys())
        ego_num_activated_alters = len(alter_set & activated_node_set)
        threshold = g.node[ego]['threshold']
        if ego_num_activated_alters >= threshold:
            # record number of active alters at activation time
            g.node[ego]['after_activation_alters'] = ego_num_activated_alters
            activation_order += 1
            g.node[ego]['activation_order'] = activation_order
            # record activation status on graph
            g.node[ego]['activated'] = 1
            activated_node_set.add(ego)
            unactivated_node_set.remove(ego)
            steps_without_activation = 0
        else:
            g.node[ego]['before_activation_alters'] = ego_num_activated_alters
            steps_without_activation += 1
            # stop condition here
            # because we randomize without replacement, if we visit a nubmer
            # of nodes equal to graph size without activation,
            # there is no node that will activate, since we have visited
            # each node at least once since the last activation
            if steps_without_activation > num_nodes:
                break
    return g

def run_sim(
    graph,
    threshold_equation,
    **kwargs
    ):
    """
    Inputs:
        graph: a graph structure with no additional annotation
        threshold_equation: a dictionary representing a threshold generating
            process. see create_thresholds for format

    Output:
        returns a dataframe with the results of the simuation
    """
    n = graph.number_of_nodes()
    thresh_and_cov = create_thresholds(
        n,
        threshold_equation,
    )
    labeled_graph = label_graph_with_thresholds(
        graph,
        thresh_and_cov,
    )
    simulated_graph = async_simulation(labeled_graph)
    list_of_record_dicts = make_csv_lines_from_sim(
        simulated_graph,
        threshold_equation,
        **kwargs,
    )
    return list_of_record_dicts

#### postprocessing functions ###############################################

def make_csv_lines_from_sim(
    graph_after_simulation,
    threshold_equation,
    **kwargs
    ):
    """
    We give this the graph resulting from the simulation

    Graph stores node data like this:
        {
            'threshold': float,
            'activated': int,
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
    """
    g = graph_after_simulation
    def subtract_or_none(x, y):
        if x != None and y != None:
            return x - y
        else:
            return None
    def rand_string():
        return ''.join([random.choice(CHARS) for _ in range(8)])

    threshold_eq_summary = {'rand_string': rand_string()}
    for var_name, var_info in threshold_equation.items():
        var_name_fmt = var_name + '_dist'
        threshold_eq_summary[var_name_fmt + '_mean'] = var_info['mean']
        threshold_eq_summary[var_name_fmt + '_sd'] = var_info['sd']
        threshold_eq_summary[var_name_fmt + '_coef'] = var_info['coefficient']
    for k, v in kwargs.items():
        threshold_eq_summary[k] = v

    list_of_record_dicts = []
    for node, node_attrs in g.nodes_iter(data=True):
        node_attrs['node'] = node
        activated = node_attrs['activated']
        after_activation_alters = node_attrs['after_activation_alters']
        before_activation_alters = node_attrs['before_activation_alters']
        difference = subtract_or_none(
            after_activation_alters,
            before_activation_alters,
        )
        if after_activation_alters == 0:
            node_attrs['observed'] = 0
        elif difference == 1:
            node_attrs['observed'] = 1
        else:
            node_attrs['observed'] = 0
        node_attrs.update(threshold_eq_summary)
        list_of_record_dicts.append(node_attrs)
    return list_of_record_dicts

#### Writer class ###########################################################

class SimWriter(object):
    """
    Handles writing sim output line-by-line to one big summary csv

    Ensures that the CSV is initialized on disk with all columns that could
    possibly occur. For instance, the 10th sim may have more columns than the
    9th because we have more variable there.

    We'd use the eq_param_cols variable to initialize the CSV with the
    appropriate rows. We would write blank columns for sims without the
    extra variables.
    """

    def __init__(self, output_path, eq_param_cols):
        self.output_path = output_path
        self.eq_param_cols = eq_param_cols
        self.all_cols = None
        self.reps = 0
        try:
            os.remove(self.output_path)
        except FileNotFoundError:
            pass

    def set_all_cols(self, list_of_record_dicts):
        """
        Sets and sorts all_cols instance variable
        """
        sim_cols = set(list_of_record_dicts[0].keys())
        self.all_cols = sorted(list(sim_cols | self.eq_param_cols))

    def write(self, list_of_record_dicts):
        if self.all_cols is None:
            self.set_all_cols(list_of_record_dicts)
        all_cols = self.all_cols
        if not os.path.isfile(self.output_path):
            with open(self.output_path, 'w') as f:
                dict_writer = csv.DictWriter(f, fieldnames=all_cols)
                dict_writer.writeheader()
        with open(self.output_path, 'a') as f:
            dict_writer = csv.DictWriter(f, fieldnames=all_cols)
            for record_dict in list_of_record_dicts:
                dict_writer.writerow(record_dict)
        self.reps += 1
        if self.reps % 100 == 0:
            print('Finished {} reps'.format(self.reps))

if __name__ == '__main__':
    #### Constants ##########################################################
    N_REPS = 1000

    threshold_eq_param_space = []
    with open(SIM_PARAM_FILE, 'r') as f:
        for line in f:
            j = json.loads(line)
            threshold_eq_param_space.append(j)
    mean_degrees = [12, 16, 20]
    graph_sizes = [1000]
    ws_rewire_probs = [.1]
    pl_cluster_probs = [.1]

    eq_param_cols = set(
        [k for d in threshold_eq_param_space for k, v in d.items()]
    )
    # these are additional sim params that we may want to play with
    eq_param_cols.update([
        'graph_type',
        'mean_deg',
        'graph_size',
        'rewire_prob',
        'cluster_prob',
    ])

    sw = SimWriter(SIM_PATH, eq_param_cols)

    # this is for purely sim graphs
    for eq in threshold_eq_param_space:
        for md in mean_degrees:
            for gs in graph_sizes:
                print("{} {} {}".format(eq, md, gs))
                for _ in range(N_REPS):
                    # ws
                    for p in ws_rewire_probs:
                        ws_graph = nx.watts_strogatz_graph(gs, md, p)
                        reps = run_sim(
                            ws_graph,
                            eq,
                            graph_type='ws',
                            mean_deg=md,
                            graph_size=gs,
                            rewire_prob=p,
                        )
                        sw.write(reps)
                    # pl w/ clustering
                    for c in pl_cluster_probs:
                        plc_graph = nx.powerlaw_cluster_graph(gs, int(md/2.), c)
                        reps = run_sim(
                            plc_graph,
                            eq,
                            graph_type='plc',
                            mean_deg=md,
                            graph_size=gs,
                            cluster_prob=c,
                        )
                        sw.write(reps)
