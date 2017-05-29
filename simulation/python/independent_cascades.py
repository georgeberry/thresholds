import random
import networkx as nx
import pandas as pd
import numpy as np

"""
Activate some seed set of random nodes

Update inactive nodes one at a time

Activate w/ some independent probability p

Record before and after exposures

Both push and pull model
"""

def pull_model(g):
    inactive_set = set(
        [n for n, attr in g.nodes_iter(data=True) if attr['active'] == 0]
    )
    # end when all checked nodes are inactive
    while True:
        inactive_itr = np.random.choice(
            list(inactive_set),
            size=len(inactive_set),
            replace=False,
        )
        newly_active_set = set()
        for n_idx in inactive_itr:
            attr = g.node[n_idx]
            nbrs = g[n_idx].keys()
            n_active_nbrs = sum([g.node[x]['active'] for x in nbrs])
            # if no active neighbors, can't activate
            if n_active_nbrs == 0:
                attr['before_exposure'] = 0
                continue
            # we may visit nodes more than once so we only want to consider
            # new neighbor activations
            if attr['before_exposure']:
                before_exposure = attr['before_exposure']
            else:
                # no lower bound recorded, this is for convenience only
                before_exposure = 0
            for trial in range(n_active_nbrs - before_exposure):
                # if successful
                if random.random() < p:
                    attr['active'] = 1
                    attr['exposure_at_activation'] = n_active_nbrs
                    attr['critical_exposure'] = before_exposure + trial + 1
                    newly_active_set.add(n_idx)
                    break
            else:
                attr['before_exposure'] = n_active_nbrs
        # stop condition: check all nodes and none activate
        if len(newly_active_set) == 0:
            break
        inactive_set = inactive_set - newly_active_set
    return g


def push_model(g):
    active_set = set(
        [n for n, attr in g.nodes_iter(data=True) if attr['active'] == 1]
    )
    # end when all checked nodes are inactive
    while True:
        active_itr = np.random.choice(
            list(active_set),
            size=len(active_set),
            replace=False,
        )
        newly_active_set = set()
        for n_idx in active_itr:
            nbrs = g[n_idx].keys()
            for nbr_idx in nbrs:
                nbr_attr = g.node[nbr_idx]
                if nbr_attr['active'] == 1:
                    continue
                nbr_nbrs = g[nbr_idx].keys()
                nbr_active_nbrs = sum(
                    [g.node[x]['active'] for x in nbr_nbrs]
                )
                if random.random() < p:
                    nbr_attr['active'] = 1
                    nbr_attr['exposure_at_activation'] = nbr_active_nbrs
                    if nbr_attr['critical_exposure']:
                        nbr_attr['critical_exposure'] += 1
                    else:
                        nbr_attr['critical_exposure'] = 1
                    newly_active_set.add(nbr_idx)
                else:
                    if nbr_attr['critical_exposure']:
                        nbr_attr['critical_exposure'] += 1
                    else:
                        nbr_attr['critical_exposure'] = 1
                    nbr_attr['before_exposure'] = nbr_active_nbrs
        # stop condition: no newly active nodes to push from
        if len(newly_active_set) == 0:
            break
        active_set = newly_active_set
    for n_idx, attr in g.nodes_iter(data=True):
        if attr['active'] == 0:
            attr['critical_exposure'] = None
    return g

seed = 42
random.seed(seed)
seed_prob = 0.03
p = 0.2

g = nx.powerlaw_cluster_graph(1000, 4, 0.1, seed=seed)
for n, attr in g.nodes_iter(data=True):
    if random.random() < seed_prob:
        attr['active'] = 1
    else:
        attr['active'] = 0
    attr['before_exposure'] = None
    attr['exposure_at_activation'] = None
    attr['critical_exposure'] = None
g = pull_model(g)
df = pd.DataFrame([attr for idx, attr in g.nodes_iter(data=True)])
df.to_csv('/Users/g/Desktop/icm_pull.tsv', sep='\t')


g = nx.powerlaw_cluster_graph(1000, 4, 0.1, seed=seed)
for n, attr in g.nodes_iter(data=True):
    if random.random() < seed_prob:
        attr['active'] = 1
    else:
        attr['active'] = 0
    attr['before_exposure'] = None
    attr['exposure_at_activation'] = None
    attr['critical_exposure'] = None
g = push_model(g)
df = pd.DataFrame([attr for idx, attr in g.nodes_iter(data=True)])
df.to_csv('/Users/g/Desktop/icm_push.tsv', sep='\t')
