"""
This does a full model output of every observation for one model run

Parameters:

graph: plc
mean degree: 12
error sd: 1
"""
import csv
import json
import networkx as nx
from constants import *
from sim_thresholds import create_thresholds,\
                           label_graph_with_thresholds,\
                           yield_random_nodes
from math import floor, ceil

def async_simulation_log(graph_with_thresholds):
    """
    Repeats the async_simulation function in sim_thresholds.py
    But writes every observation to a file on disk
    In other words, we record every activation
    """
    g = graph_with_thresholds
    all_node_set = set(g.nodes_iter())
    num_nodes = len(all_node_set)

    activated_node_set = set()
    unactivated_node_set = all_node_set

    steps_without_activation = 0
    activation_order = 0
    iteration = 0
    node_rand_seq = yield_random_nodes(unactivated_node_set)

    with open(ONE_OFF_DF_PATH, 'w') as outfile:
        writer = csv.DictWriter(
            outfile,
            fieldnames=['epsilon',
                        'threshold',
                        'exposure',
                        'activation_order',
                        'iteration',
                        'activated',
                        'after_activation_alters',
                        'var1',
                        'constant',
                        'before_activation_alters'],
            extrasaction='ignore')
        writer.writeheader()
        while len(unactivated_node_set) > 0:
            try:
                ego = next(node_rand_seq)
            except StopIteration:
                node_rand_seq = yield_random_nodes(unactivated_node_set)
                ego = next(node_rand_seq)
            if ego in activated_node_set:
                continue
            iteration += 1
            alter_set = set(g[ego].keys())
            ego_num_activated_alters = len(alter_set & activated_node_set)
            threshold = g.node[ego]['threshold']
            g.node[ego]['iteration'] = iteration
            g.node[ego]['exposure'] = ego_num_activated_alters
            if ego_num_activated_alters >= threshold:
                g.node[ego]['after_activation_alters'] =\
                    ego_num_activated_alters
                activation_order += 1
                g.node[ego]['activation_order'] = activation_order
                # record activation status on graph
                g.node[ego]['activated'] = 1
                activated_node_set.add(ego)
                unactivated_node_set.remove(ego)
                steps_without_activation = 0
                writer.writerow(g.node[ego])
            else:
                g.node[ego]['before_activation_alters'] = \
                    ego_num_activated_alters
                steps_without_activation += 1
                writer.writerow(g.node[ego])
                if steps_without_activation > num_nodes:
                    break

if __name__ == '__main__':
    eq = {
        'epsilon': {'distribution': 'epsilon',
                    'mean': 0,
                    'sd': 1.0,
                    'coefficient': None},
        'var1': {'distribution': 'normal',
                 'mean': 0,
                 'sd': 1.0,
                 'coefficient': 3.0},
        'constant': {'distribution': 'constant',
                     'mean': None,
                     'sd': None,
                     'coefficient': 5}}
    mean_deg = 12
    graph_size = 1000
    cluster_prob = 0.1

    plc_graph = nx.powerlaw_cluster_graph(
        graph_size,
        int(mean_deg/2.),
        cluster_prob,
    )
    thresh_and_cov = create_thresholds(
        graph_size,
        eq,
    )
    labeled_graph = label_graph_with_thresholds(
        plc_graph,
        thresh_and_cov,
    )
    simulated_graph = async_simulation_log(labeled_graph)

    # ideal randomized control trial world
    with open(ONE_OFF_DF_PATH, 'r') as infile:
        reader = csv.DictReader(infile)
        with open(ONE_OFF_IDEAL_DF_PATH, 'w') as outfile:
            writer = csv.DictWriter(outfile,
                                    fieldnames=['epsilon',
                                                'threshold',
                                                'exposure',
                                                'activation_order',
                                                'iteration',
                                                'activated',
                                                'after_activation_alters',
                                                'var1',
                                                'constant',
                                                'before_activation_alters'])
            writer.writeheader()
            for row in reader:
                if row['activated'] == '1':
                    # assume they activated at "right" time
                    row['exposure'] = str(max(0, ceil(float(row['threshold']))))
                    writer.writerow(row)
                    thresh_floor = max(0, floor(float(row['threshold'])))
                    # go back through previous exposures
                    row['activated'] = '0'
                    for prev_exposure in range(thresh_floor + 1):
                        row['exposure'] = str(prev_exposure)
                        writer.writerow(row)
