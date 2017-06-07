import random
import networkx as nx
import pandas as pd
import numpy as np
import csv

"""
Classes:
    - BaseSim
    - ICMBase(BaseSim)
    - ThresholdBase(BaseSim)
    - ICMPullModel(ICMBase)
    - ICMPushModel(ICMBase)
    - IntThresholdModel(BaseSim)
    - FracThresholdModel(BaseSim)

See BaseSim for important methods

Functions:
    - normal_threhsold_distribution
    - exponential_threshold_distribution
    - uniform_threshold_distribution

"""

#### Simulation base class #####################################################

class BaseSim(object):
    """
    - inputs
        g: a graph
        subclass arguments
    - outputs
        records: [{node1_data}, {node2_data}, ...]

    Provides standard methods for sim dynamics, stopping rule, output
    Override the rest yourself
    """
    def __init__(self):
        """
        We store arguments on the class
        - Ovderride in subclass
        """
        raise NotImplementedError

    def preprocess_graph(self, g):
        """
        Called once to add the appropriate fields to the graph
        Should return graph copy
        - Override in subclass
        """
        raise NotImplementedError

    def simulation_epoch(self):
        """
        One update run of the simulation
        Usually this will include going through all nodes once
        Having this update one node is fine, but it will be slower
        - Override in subclass
        """
        raise NotImplementedError

    def stop_rule(self):
        """
        Check all nodes and none activate
        - This method should not be overridden
        """
        # stop condition: no newly active nodes to push from
        if len(self.newly_active_set) == 0:
            return True
        return None

    def generate_output(self):
        """
        Generates records for output
        - This method should not be overriden
        """
        records = [attr for n, attr in self.g.nodes_iter(data=True)]
        for record in records:
            record['name'] = self.name
        return records

    def dynamics(self):
        """
        Method to run the simulation and return output
        - This method should not be overriden
        """
        while True:
            self.simulation_epoch()
            if self.stop_rule():
                break
        return self.generate_output()

    def get_inactive_itr(self):
        if len(self.inactive_set) > 0:
            inactive_itr = np.random.choice(
                list(self.inactive_set),
                size=len(self.inactive_set),
                replace=False,
            )
        else:
            inactive_itr = []
        return inactive_itr

#### Intermediate classes based on sim type ####################################

class ICMBase(BaseSim):
    """
    You need to definite __init__ and simulation_epoch in subclass
    """
    def __init__(self):
        raise NotImplementedError

    def preprocess_graph(self, g):
        """
        Called once to add the appropriate fields to the graph
        Returns a graph copy

        """
        seed_nodes = set(random.sample(
            list(g.node.keys()), # list to sample from
            round(self.s * len(g)), # number of seeds
        ))
        for n, attr in g.nodes_iter(data=True):
            attr['active'] = 0
            if n in seed_nodes:
                attr['active'] = 1
            attr['before_exposure'] = None
            attr['exposure_at_activation'] = None
            attr['critical_exposure'] = None
        return g.copy()

    def simulation_epoch(self):
        raise NotImplementedError


class ThresholdBase(BaseSim):
    """
    Threshold model base, fill in your simulation_epoch function in a subclass
    """
    def __init__(self, g, t, name):
        """
        g: graph
        t: threshold vector
        """
        self.name = name
        self.g = self.preprocess_graph(g, t)
        self.inactive_set = set(
            [n for n, attr in self.g.nodes_iter(data=True)
             if attr['active'] == 0]
        )
        self.newly_active_set = set()

    def preprocess_graph(self, g, t):
        """
        Called once to add the appropriate fields to the graph
        Returns a graph copy
        """
        for n, attr in g.nodes_iter(data=True):
            attr['active'] = 0
            attr['before_exposure'] = None
            attr['exposure_at_activation'] = None
            attr['critical_exposure'] = t[n]
            attr['threshold'] = t[n]
        return g.copy()

    def simulation_epoch(self):
        raise NotImplementedError


#### Classes that actually run sims ############################################

class ICMPullModel(ICMBase):
    """
    ICM model where each node updates and "pulls" the contagion to it
    """
    def __init__(self, g, p, s, name):
        """
        inputs
            g: a graph
            p: independent activation probability
            s: proportion of graph to seed
        """
        self.p = p
        self.s = s
        self.name = name
        self.g = self.preprocess_graph(g)
        self.inactive_set = set(
            [n for n, attr in self.g.nodes_iter(data=True)
             if attr['active'] == 0]
        )
        self.newly_active_set = set()

    def simulation_epoch(self):
        """
        One update run of the simulation
        """
        inactive_itr = self.get_inactive_itr()
        self.newly_active_set = set()
        for n_idx in inactive_itr:
            attr = self.g.node[n_idx]
            nbrs = self.g[n_idx].keys()
            n_active_nbrs = sum([self.g.node[x]['active'] for x in nbrs])
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
                if random.random() < self.p:
                    attr['active'] = 1
                    attr['exposure_at_activation'] = n_active_nbrs
                    attr['critical_exposure'] = before_exposure + trial + 1
                    self.newly_active_set.add(n_idx)
                    break
            else:
                attr['before_exposure'] = before_exposure + n_active_nbrs
        self.inactive_set = self.inactive_set - self.newly_active_set


class ICMPushModel(ICMBase):
    """
    ICM model where each node updates and "pulls" the contagion to it
    """
    name='icm_pull'
    def __init__(self, g, p, s, name):
        """
        inputs
            g: a graph
            p: independent activation probability
            s: proportion of graph to seed
        """
        self.p = p
        self.s = s
        self.name = name
        self.g = self.preprocess_graph(g)
        self.newly_active_set = set(
            [n for n, attr in self.g.nodes_iter(data=True)
             if attr['active'] == 1]
        )

    def simulation_epoch(self):
        """
        One update run of the simulation
        """
        active_itr = np.random.choice(
            list(self.newly_active_set),
            size=len(self.newly_active_set),
            replace=False,
        )
        self.newly_active_set = set()
        for n_idx in active_itr:
            nbrs = self.g[n_idx].keys()
            for nbr_idx in nbrs:
                nbr_attr = self.g.node[nbr_idx]
                if nbr_attr['active'] == 1:
                    continue
                nbr_nbrs = g[nbr_idx].keys()
                nbr_active_nbrs = sum(
                    [self.g.node[x]['active'] for x in nbr_nbrs]
                )
                if random.random() < self.p:
                    nbr_attr['active'] = 1
                    nbr_attr['exposure_at_activation'] = nbr_active_nbrs
                    try:
                        nbr_attr['critical_exposure'] += 1
                    except:
                        nbr_attr['critical_exposure'] = 1
                    self.newly_active_set.add(nbr_idx)
                else:
                    try:
                        nbr_attr['critical_exposure'] += 1
                    except:
                        nbr_attr['critical_exposure'] = 1
                    nbr_attr['before_exposure'] = nbr_active_nbrs


class IntThresholdModel(ThresholdBase):
    """
    Threshold model where each node has an integer activation threshold
    """
    name='int_thresh'
    def simulation_epoch(self):
        """
        One update run of the simulation
        """
        inactive_itr = self.get_inactive_itr()
        self.newly_active_set = set()
        for n_idx in inactive_itr:
            attr = self.g.node[n_idx]
            nbrs = self.g[n_idx].keys()
            th = attr['threshold']
            n_active_nbrs = sum([self.g.node[x]['active'] for x in nbrs])
            if n_active_nbrs >= th:
                attr['active'] = 1
                attr['exposure_at_activation'] = n_active_nbrs
                self.newly_active_set.add(n_idx)
            else:
                attr['before_exposure'] = n_active_nbrs
        self.inactive_set = self.inactive_set - self.newly_active_set


class FracThresholdModel(ThresholdBase):
    """
    Threshold model where each node has a fractional threshold
    """
    name='frac_thresh'
    def simulation_epoch(self):
        """
        One update run of the simulation
        """
        inactive_itr = self.get_inactive_itr()
        self.newly_active_set = set()
        for n_idx in inactive_itr:
            attr = self.g.node[n_idx]
            nbrs = self.g[n_idx].keys()
            th = attr['threshold']
            active_list = [self.g.node[x]['active'] for x in nbrs]
            frac_active_nbrs = sum(active_list) / len(active_list)
            if frac_active_nbrs >= th:
                attr['active'] = 1
                attr['exposure_at_activation'] = frac_active_nbrs
                self.newly_active_set.add(n_idx)
            else:
                attr['before_exposure'] = frac_active_nbrs
        self.inactive_set = self.inactive_set - self.newly_active_set


#### distribution generating functions #########################################

def set_seeds(th_vector, seed_frac):
    n_nodes = len(th_vector)
    seed_num = round(seed_frac * n_nodes)
    already_existing_seeds = sum([x <= 0.0 for x in th_vector])
    seeds_to_add = seed_num - already_existing_seeds
    if seeds_to_add > 0:
        seed_idxs = random.sample(
            range(n_nodes),
            seeds_to_add,
        )
        for idx in seed_idxs:
            th_vector[idx] = 0.0
    return th_vector

def normal_threhsold_distribution(n=1000, mean=5, sd=1, seed_frac=0.01):
    th = np.ceil(np.random.normal(loc=mean, scale=sd, size=n))
    return set_seeds(np.array(th), seed_frac)

def exponential_threshold_distribution(n=1000, beta=3, seed_frac=0.01):
    th = np.ceil(np.random.exponential(scale=beta, size=n))
    return set_seeds(np.array(th), seed_frac)

def uniform_threshold_distribution(n=1000, min=0, max=10, seed_frac=0.01):
    th = np.ceil(np.random.randint(0,10,size=gsize))
    return set_seeds(np.array(th), seed_frac)

# diagnostic fns

def print_diagnostics(df):
    print(sum(df.active))
    print(df[['before_exposure', 'exposure_at_activation', 'critical_exposure']].head())
    #print(df.exposure_at_activation - df.critical_exposure)


if __name__ == '__main__':
    # seed = 42
    # random.seed(seed)
    p = 0.2
    s = 0.05
    gsize = 1000
    n_runs = 100

    count = 0

    with open('/Users/g/Desktop/new_sim_runs.tsv', 'w') as outfile:
        fieldnames = [
            'active',
            'before_exposure',
            'exposure_at_activation',
            'critical_exposure',
            'threshold',
            'name'
        ]
        w = csv.DictWriter(outfile, fieldnames=fieldnames, delimiter='\t')
        w.writeheader()
        for sim_idx in range(n_runs):
            count += 1
            g = nx.barabasi_albert_graph(gsize, 6)


            # threshold dists
            int_norm_dist = normal_threhsold_distribution(
                n=len(g),
                mean=5,
                sd=1,
                seed_frac=s,
            )
            int_exp_dist = exponential_threshold_distribution(
                n=len(g),
                beta=3,
                seed_frac=s,
            )
            int_unif_dist = uniform_threshold_distribution(
                n=len(g),
                min=0,
                max=11,
                seed_frac=s,
            )
            frac_norm_dist = 0.5 * (int_norm_dist / np.max(int_norm_dist))
            frac_exp_dist = int_exp_dist / np.max(int_exp_dist)
            frac_unif_dist = 0.75 * (int_unif_dist / np.max(int_unif_dist))
            frac_cons_dist = set_seeds(
                np.zeros((1000,)) + .2,
                s,
            )

            results = [
                ICMPushModel(
                    g,
                    p=p,
                    s=s,
                    name='icm_push',
                ).dynamics(),
                ICMPullModel(g,
                    p=p,
                    s=s,
                    name='icm_pull',
                ).dynamics(),
                IntThresholdModel(g,
                    int_norm_dist,
                    name='th_int_norm',
                ).dynamics(),
                IntThresholdModel(g,
                    int_exp_dist,
                    name='th_int_exp',
                ).dynamics(),
                IntThresholdModel(g,
                    int_unif_dist,
                    name='th_int_unif',
                ).dynamics(),
                FracThresholdModel(g,
                    frac_norm_dist,
                    name='th_frac_norm',
                ).dynamics(),
                FracThresholdModel(g,
                    frac_exp_dist,
                    name='th_frac_exp',
                ).dynamics(),
                FracThresholdModel(g,
                    frac_unif_dist,
                    name='th_frac_unif',
                ).dynamics(),
                FracThresholdModel(g,
                    frac_cons_dist,
                    name='th_frac_cons',
                ).dynamics(),
            ]
            for res in results:
                for elem in res:
                    w.writerow(elem)
            print('done with run {}'.format(count))
