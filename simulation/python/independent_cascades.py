import random
import networkx as nx
import pandas as pd

"""
Activate some seed set of random nodes

Update inactive nodes one at a time

Activate w/ some independent probability p

Record before and after exposures
"""

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

inactive_set = set(
    [n for n, attr in g.nodes_iter(data=True) if attr['active'] == 0]
)
while len(inactive_set) > 0:
    newly_active_set = set()
    for n_idx in inactive_set:
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
            checked_inactive_set.add(n_idx)
    if len(newly_active_set) == 0:
        break
    inactive_set = inactive_set - newly_active_set

df = pd.DataFrame([attr for idx, attr in g.nodes_iter(data=True)])

df.to_csv('/Users/g/Desktop/icm.tsv', sep='\t')
