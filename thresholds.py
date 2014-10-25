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

    Allows easy creation/storage/iteration/logging of various graphs with various threshold functions

    Specifically, consider theta_i(X_i), i's threshold as a function of a vector of individual covariates
    This class provides the gen_thresholds classmethod for generating the 2-tuple:
        ([thresholds,...],[{cov_name:cov_value},...])
        In words: 
            The first element of the tuple is an ordered list of thresholds
            The second element of the tuple is an ordered list of tuples containing the covariates for each individual
            So taking thresholds[0] and covariates[0] gives the threshold and covariates for individual 1

    '''
    def __init__(self, rand_graph_type='regular', threshold_type='integer', thresholds=2, covariates=None, neighbors=10, num_nodes=1000, seed_fraction = 0.03):

        self.df = pd.DataFrame(columns=('ego','activated','activated alters', 'timestep', 'covariates', 'true threshold'))
        self.create_random_graph(rand_graph_type, neighbors, num_nodes)
        self.set_thresholds(thresholds, covariates)
        self.seed_nodes(seed_fraction) #looks good up to here


    def create_random_graph(self, rand_graph_type, neighbors, num_nodes):
        assert rand_graph_type in {'regular', 'watts-strogatz', 'power law', 'poisson'}, 'OMG I DONT RECOGNIZE THAT GRAPH TYPE'
        if rand_graph_type == 'regular':
            self.g = nx.random_regular_graph(neighbors, num_nodes)

        #set time to 0
        self.g.graph['timestep'] = 0


    def set_thresholds(self, thresholds, covariates):
        #everyone has same thresholds
        if type(thresholds) == int:
            for node in self.g.nodes_iter():
                self.g.node[node]['threshold'] = thresholds
                self.g.node[node]['covariates'] = None
        #if iterable, assign in order to nodes
        elif hasattr(thresholds, '__iter__') and covariates == None: 
            assert len(thresholds) == g.order(), 'OMG WRONG NUMBER OF THRESHOLDS'
            for idx, node in enumerate(self.g.nodes_iter()):
                self.g.node[node]['threshold'] = thresholds[idx]
                self.g.node[node]['covariates'] = None
        elif hasattr(thresholds, '__iter__') and covariates != None: 
            assert len(thresholds) == self.g.order(), 'OMG WRONG NUMBER OF THRESHOLDS OR COVARIATES'
            print 'cov'
            for idx, node in enumerate(self.g.nodes_iter()):
                self.g.node[node]['threshold'] = thresholds[idx]
                self.g.node[node]['covariates'] = covariates[idx]


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

        #print new_graph.size()
        #print new_graph.order()

        for ego in self.g.nodes_iter():
            #print new_graph.node[ego]
            if self.g.node[ego]['activated'] == 1:
                #print self.g.node[ego]
                #print 'passing'
                #no need to evaluate if already activated
                continue
            activated_alters = 0
            for alter in new_graph[ego]:
                activated_alters += self.g.node[alter]['activated']
            if activated_alters >= self.g.node[ego]['threshold']:
                new_graph.node[ego]['activated'] = 1
            if new_graph.node[ego]['covariates'] != None:
                self.add_node_to_df(ego, new_graph.node[ego]['activated'], activated_alters, new_graph.graph['timestep'], new_graph.node[ego]['threshold'], new_graph.node[ego]['covariates'])
            else:
                self.add_node_to_df(ego, new_graph.node[ego]['activated'], activated_alters, new_graph.graph['timestep'], new_graph.node[ego]['threshold'])
        self.g = new_graph


    def add_node_to_df(self, ego, activated, activated_alters, timestep, true_threshold, covariate=None):
        rows, cols = self.df.shape
        self.df.loc[rows + 1] = [ego, activated, activated_alters, timestep, covariate, true_threshold]

    def __call__(self, num_iter=10):
        for _ in range(num_iter):
            self.update()


    def number_activated(self):
        pass


    @timer
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
        self.pruned_df = pd.DataFrame(columns=('ego','activated','activated alters','timestep','covariates', 'true threshold'))
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

            #if max_unactivated_row['covariates'].iloc[0] == 2:
            #    print '-'*50
            #    print max_unactivated_row
            #    print min_activated_row

            #we need to assure that we're getting the actual adoption exposure
            if min_activated_row['activated alters'].iloc[0] - max_unactivated_row['activated alters'].iloc[0] != 1:
                continue

            rows, cols = self.pruned_df.shape
            self.pruned_df.loc[rows + 1] = min_activated_row.as_matrix()

    @timer
    def clean_df(self):
        #just first time individuals adopt
        cleaned_df = pd.DataFrame(columns=('ego','activated','activated alters','timestep','covariates', 'true threshold'))

        df = self.df.loc[self.df['activated'] == 1]
        for ego in set(df['ego']):
            unactivated_df = df.loc[(df['ego'] == ego) & (df['activated'] == 0)]
            activated_df = df.loc[(df['ego'] == ego) & (df['activated'] == 1)]

            #for seeds
            #if unactivated_df.shape[0] == 0 or activated_df.shape[0] == 0:
            #    continue

            #max_time_unactivated = max(unactivated_df['timestep'])
            min_time_activated = min(activated_df['timestep'])

            #max_unactivated_row = df.loc[(df['ego'] == ego) & (df['activated'] == 0) & (df['timestep'] == max_time_unactivated)]
            min_activated_row = df.loc[(df['ego'] == ego) & (df['activated'] == 1) & (df['timestep'] == min_time_activated)]

            #if max_unactivated_row['covariates'].iloc[0] == 2:
            #    print '-'*50
            #    print max_unactivated_row
            #    print min_activated_row

            #we need to assure that we're getting the actual adoption exposure
            #if min_activated_row['activated alters'].iloc[0] - max_unactivated_row['activated alters'].iloc[0] != 1:
            #    continue

            rows, cols = cleaned_df.shape
            cleaned_df.loc[rows + 1] = min_activated_row.as_matrix() 
        return cleaned_df

    @timer
    def OLS(self, pruned=True):
        if pruned:
            df = self.pruned_df
        else:
            df = self.clean_df()
        y = df['activated alters']
        covariate = df['covariates']
        constant = pd.Series([1]*covariate.shape[0], index=covariate.index)
        X = pd.DataFrame({'constant': constant, 'covariates': covariate})
        y = y.as_matrix()
        X = X.as_matrix()

        #print type(y)
        #print X
        #h = X * la.inv(X.T * X) * X.T
        beta = np.dot(np.dot(la.inv(np.dot(X.T, X)), X.T),y)
        return beta

    @classmethod
    def gen_thresholds(self, num_nodes=1000, **kwargs):
        '''
        kwargs should be of the form ('covariate name': beta value)

        actual individual-level variables are pulled from a normal(0,1) distribution
        '''
        for 



if __name__ == '__main__':
    #thresholds = [1]*500 + [2]*500
    #shuffle(thresholds)
    #covariates = [x - 1 for x in thresholds]
    thresholds = [1]*500 + [3]*500
    shuffle(thresholds)
    covariates = [x - 1 if x == 1 else x - 2 for x in thresholds]

    tg = ThresholdGraph(nodes = 1000, neighbors=15, thresholds=thresholds, covariates=covariates)
    tg(5)
    tg.prune()
    #print tg.pruned_df
    print tg.OLS()
    print tg.OLS(pruned=False) #really, really wrong