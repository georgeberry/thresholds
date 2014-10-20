import networkx as nx
import statsmodels.api as sm
import pandas as pd
import numpy as np
import numpy.linalg as la
from random import random, shuffle
from copy import deepcopy
from time import time
from functools import wraps


def timer(f):
    '''
    timer decorator
    '''
    @wraps(f)
    def wrapper(*args,**kwargs):
        tic = time()
        result = f(*args, **kwargs)
        print(f.__name__ + " took " + str(time() - tic) + " seconds")
        return result
    return wrapper


class ThresholdGraph(object):
    '''
    graph structure is fixed

    allows easy creation/storage/iteration/logging of various graphs with various thresholds
    '''
    def __init__(self, rand_graph_type='regular', threshold_type='integer', thresholds=2, covariates=None, neighbors=10, nodes=1000, seed_fraction = 0.01):

        self.df = pd.DataFrame(columns=('ego','activated','activated alters', 'timestep', 'covariate'))
        self.create_random_graph(rand_graph_type, neighbors, nodes)
        self.set_thresholds(thresholds, covariates)
        self.seed_nodes(seed_fraction)


    def create_random_graph(self, rand_graph_type, neighbors, nodes):
        assert rand_graph_type in {'regular', 'watts-strogatz', 'power law', 'poisson'}, 'OMG I DONT RECOGNIZE THAT GRAPH TYPE'
        if rand_graph_type == 'regular':
            self.g = nx.random_regular_graph(neighbors, nodes)

        #set time to 0
        self.g.graph['timestep'] = 0


    def set_thresholds(self, thresholds, covariates):
        #everyone has same thresholds
        if type(thresholds) == int:
            for node in self.g.nodes_iter():
                self.g.node[node]['threshold'] = thresholds
                self.g.node[node]['covariate'] = None
        #if iterable, assign in order to nodes
        elif hasattr(thresholds, '__iter__') and covariates == None: 
            assert len(thresholds) == g.order(), 'OMG WRONG NUMBER OF THRESHOLDS'
            for idx, node in enumerate(self.g.nodes_iter()):
                self.g.node[node]['threshold'] = thresholds[idx]
                self.g.node[node]['covariate'] = None
        elif hasattr(thresholds, '__iter__') and covariates != None: 
            assert len(thresholds) == self.g.order(), 'OMG WRONG NUMBER OF THRESHOLDS OR COVARIATES'
            for idx, node in enumerate(self.g.nodes_iter()):
                self.g.node[node]['threshold'] = thresholds[idx]
                self.g.node[node]['covariate'] = covariates[idx]


    def seed_nodes(self, seed_fraction):
        for node in self.g.nodes_iter():
            rndm = random()
            if rndm >= 1 - seed_fraction:
                self.g.node[node]['activated'] = 1
            else:
                self.g.node[node]['activated'] = 0


    @timer
    def update(self):
        '''
        Update rule for the graph
        Call once to perform one iteration
        '''
        new_graph = deepcopy(self.g)
        new_graph.graph['timestep'] += 1

        for ego in new_graph.nodes_iter():
            if self.g.node[ego]['activated'] == 1:
                #print 'passing'
                #no need to evaluate if already activated
                continue
            activated_alters = 0
            for alter in new_graph[ego]:
                activated_alters += self.g.node[alter]['activated']
            if activated_alters >= self.g.node[ego]['threshold']:
                new_graph.node[ego]['activated'] = 1
            if new_graph.node[ego]['covariate']:
                self.add_node_to_df(ego, new_graph.node[ego]['activated'], activated_alters, new_graph.graph['timestep'], new_graph.node[ego]['covariate'])
            else:
                self.add_node_to_df(ego, new_graph.node[ego]['activated'], activated_alters, new_graph.graph['timestep'])
        self.g = new_graph


    def add_node_to_df(self, ego, activated, activated_alters, timestep, covariate=None):
        rows, cols = self.df.shape
        if covariate:
            pass
        else:
            self.df.loc[rows + 1] = [ego, activated, activated_alters, timestep, covariate]


    def __call__(self, num_iter=10):
        for _ in range(num_iter):
            self.update()


    def number_activated(self):
        pass


    def prune(self):
        '''
        throw out all but last unactivated and first activated

        for each i, max(t) : y = 0
        for each i, min(t) : y = 1

        keep only if diffrence in alters == 1

        this is the most restrictive way of doing this
        we can approx it by giving (after - before / 2), where n is the jump
        '''
        df = self.df
        self.pruned_df = pd.DataFrame(columns=('ego','activated','activated alters','timestep','covariate'))
        indexes = df['ego']
        for ego in set(indexes):
            unactivated_df = df.loc[(df['ego'] == ego) & (df['activated'] == 0)]
            activated_df = df.loc[(df['ego'] == ego) & (df['activated'] == 1)]

            #for seeds
            if unactivated_df.shape[0] == 0 or activated_df.shape[0] == 0:
                continue

            max_time_unactivated = max(unactivated_df['timestep'])
            min_time_activated = min(activated_df['timestep'])

            max_unactivated_row = df.loc[(df['ego'] == ego) & (df['activated'] == 0) & (df['timestep'] == max_time_unactivated)]
            min_activated_row = df.loc[(df['ego'] == ego) & (df['activated'] == 1) & (df['timestep'] == min_time_activated)]

            #print '-'*50
            #print max_unactivated_row
            #print min_activated_row

            #we need to assure that we're getting the actual adoption exposure
            if min_activated_row['activated alters'].iloc[0] - max_unactivated_row['activated alters'].iloc[0] != 1:
                continue

            rows, cols = self.pruned_df.shape
            self.pruned_df.loc[rows + 1] = min_activated_row.as_matrix()


    def OLS(self, pruned=True):
        if pruned:
            df = self.pruned_df
        else:
            df = self.df
        y = df['activated']
        activated = df['activated alters']
        constant = pd.Series([1]*activated.shape[0], index=activated.index)
        X = pd.DataFrame({'constant': constant, 'activated alters': activated})
        y = y.as_matrix()
        X = X.as_matrix()

        #print type(y)
        #print X
        #h = X * la.inv(X.T * X) * X.T
        beta = np.dot(np.dot(la.inv(np.dot(X.T, X)), X.T),y)
        return beta


#first test

thresholds = [1]*500 + [2]*500
covariates = [0]*500 + [1]*500
shuffle(thresholds)
shuffle(covariates)


tg = ThresholdGraph(nodes = 1000, thresholds=thresholds, covariates=covariates)
tg(10)
tg.prune()
print tg.pruned_df
print tg.OLS()

#y = tg.df['activated']
#X = tg.df['activated alters']
#X = sm.add_constant(X)

'''
#this will be really, really wrong
#even though the model is really, really "sure"
#high R^2 is interesting
model = sm.OLS(y,X)
results = model.fit()
print(results.summary())

#logit is also junk
model = sm.Logit(y,X)
results = model.fit()
print(results.summary())

#throw out all observations after we observe a switch
#this gets us closer
new_df = pd.DataFrame(columns=('ego', 'activated', 'activated alters', 'wave'))
tracker = {x:0 for x in g.nodes_iter()}

for row in df.index:
    rows, cols = new_df.shape
    ego = df.loc[row]['ego']
    activated = df.loc[row]['activated']
    r = df.loc[row]
    if tracker[ego] == 0:
        if activated == 1:
            tracker[ego] = 1
            new_df.loc[rows+1] = list(r)
        else:
            new_df.loc[rows+1] = list(r)

y = new_df['activated']
X = new_df['activated alters']
X = sm.add_constant(X)

#this will be really, really wrong
#even though the model is really, really "sure"
#high R^2 is interesting
model = sm.OLS(y,X)
results = model.fit()
print(results.summary())


# what if we were to throw out all observations where the individual did not have 1, 2, 3, etc. exposures
# so if a person's first exposure was with 3 friends, we throw that out




#second test

#probablistic model, something like an SIR

'''