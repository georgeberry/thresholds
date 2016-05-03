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

from sim_thresholds import async_simulation
from sim_thresholds import eq_to_str
from sim_thresholds import get_column_ordering
from sim_thresholds import make_dataframe_from_simulation
from sim_thresholds import async_simulation
from sim_thresholds import random_sequence
from sim_thresholds import timer

"""
Very similar to sim_thresholds.py
Except tailored to take empirical topologies in .graphml

Changes from sim_thresholds.py:
    1) Label nodes with covariates then create thresholds
    2) Save to different folder
    3) Read different param file
"""

def graph_path_to_id(graph_path):
    spl_list = graph_path.split('/')
    school_with_ftype = spl_list[-1]
    school = school_with_ftype.split('.')[0]
    return school

def output_id_empirical(eq, graph_path):
    eq_str = eq_to_str(eq)
    school = graph_path_to_id(graph_path)
    id_str = '___'.join([eq_str, school])
    return id_str

def label_graph_with_thresholds_empirical(graph, eq):
    n = nx.number_of_nodes(graph)
    degree = nx.degree_centrality(graph)

    keys = set(eq.keys())
    keys -= set(['constant', 'epsilon'])
    assert len(keys) == 1, 'More than 1 var name found'
    var_name = list(keys)[0]

    constant = float(eq['constant']['coefficient'])
    epsilon_sd = float(eq['epsilon']['sd'])

    all_epsilons = np.random.normal(0.0, epsilon_sd, n)
    # the eq only has constant, epsilon, and the var
    var_data = eq[var_name]
    var_coef = float(var_data['coefficient'])
    for idx, (node, node_attrs) in enumerate(graph.nodes_iter(data=True)):
        node_attrs['activated'] = False
        node_attrs['before_activation_alters'] = None
        node_attrs['after_activation_alters'] = None
        node_var_val = node_attrs[var_name]
        threshold = constant + var_coef * node_var_val + all_epsilons[idx]
        node_attrs['threshold'] = threshold
        node_attrs['degree'] = degree[node]
        node_attrs['var1'] = node_var_val
        node_attrs['var_name'] = var_name
    return graph

def run_sim_empirical(output_path, graph, eq):
    """
    Labels graph with thresholds according to eq
    Does the simulation
    Saves to disk
    """
    # This is the main difference from the sim graph code
    # We go through the graph to label thresholds according to eq
    labeled_graph = label_graph_with_thresholds_empirical(
        graph,
        eq,
    )
    simulated_graph = async_simulation(labeled_graph)
    df = make_dataframe_from_simulation(simulated_graph)
    print('Num activated {}; Num observed {}'.format(
        sum(df.activated),
        sum(df.observed)
    ))
    df.to_csv(output_path)

@timer
def sim_reps_empirical(n_rep, output_id, graph, eq):
    for sim_num in range(n_rep):
        output_path = OUTPUT_FOLDER + output_id + '~' + str(sim_num)
        run_sim_empirical(output_path, graph, eq)

if __name__ == '__main__':
    ## Constants ##

    N_REPS = 100
    EMPIRICAL_GRAPH_FOLDER = '../data/graphml_graphs/'
    OUTPUT_FOLDER = '../data/empirical_replicants/'
    THRESHOLD_PARAM_FILE = '../data/empirical_param_space.json'

    graph_paths = [
        EMPIRICAL_GRAPH_FOLDER + x for x in os.listdir(EMPIRICAL_GRAPH_FOLDER)
    ]

    print('graph paths are {}'.format(graph_paths))

    threshold_eq_param_space = []
    with open(THRESHOLD_PARAM_FILE, 'rb') as f:
        for line in f:
            j = json.loads(line)
            threshold_eq_param_space.append(j)

    print('param space is {}'.format(threshold_eq_param_space))

    ## Read Graphs ##
    for graph_path in graph_paths:
        g = nx.read_graphml(graph_path)
        for eq in threshold_eq_param_space:
            # read here
            print('graph has {} nodes and {} edges'.format(
                nx.number_of_nodes(g),
                nx.number_of_edges(g),
            ))
            # output id
            output_id = output_id_empirical(eq, graph_path)
            # very run
            sim_reps_empirical(N_REPS, output_id, g, eq)
