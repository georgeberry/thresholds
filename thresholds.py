import networkx as nx
import statsmodels.api as sm
import pandas as pd
import numpy as np
import numpy.linalg as la
from random import random, gauss, randint, uniform, shuffle, choice
from copy import deepcopy
from time import time
from functools import wraps
from scipy.stats import norm


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
    graph structure is fixed for convenience, although this is not a strict assumption of the model

    Allows easy creation/storage/iteration/logging of various graphs with various threshold functions

    Specifically, consider theta_i(X_i), i's threshold as a function of a vector of individual covariates
    This class provides the gen_thresholds classmethod for generating the 2-tuple:
        ([thresholds,...],[{cov_name:cov_value},...])
        In words: 
            The first element of the tuple is an ordered list of thresholds
            The second element of the tuple is an ordered list of tuples containing the covariates for each individual
            So taking thresholds[0] and covariates[0] gives the threshold and covariates for individual 1

    '''
    def __init__(self, thresholds, covariates=None, rand_graph_type='regular', threshold_type='integer', neighbors=10, num_nodes=1000): #, seed_fraction = 0.01):

        if covariates:
            self.covariate_names = sorted(covariates[0].keys())
        self.pruned_df = None
        self.pruned_exists = False

        #add covariate names and make pandas df
        df_colnames = ['ego','activated','activated alters', 'timestep', 'true threshold']
        df_colnames.extend(self.covariate_names) #sort alphabetically
        self.df = pd.DataFrame(columns=tuple(df_colnames))

        #creates just graph structure
        self.create_random_graph(rand_graph_type, neighbors, num_nodes)

        #set thresholds and assign covariates as node attributes
        self.set_thresholds(thresholds, covariates)

        #flip seed nodes on
        #self.seed_nodes(seed_fraction)


    def create_random_graph(self, rand_graph_type, neighbors, num_nodes):
        assert rand_graph_type in {'regular', 'watts-strogatz', 'power law', 'poisson'}, 'OMG I DONT RECOGNIZE THAT GRAPH TYPE'
        if rand_graph_type == 'regular':
            self.g = nx.random_regular_graph(neighbors, num_nodes)
        if rand_graph_type == 'watts-strogatz':
            self.g = nx.watts_strogatz_graph(num_nodes, neighbors, .01)
        if rand_graph_type == 'poisson':
            self.g = nx.gnp_random_graph(num_nodes, float(neighbors)/num_nodes)
        if rand_graph_type == 'power law':
            self.g = nx.powerlaw_cluster_graph(num_nodes, 4, .2)
            print self.g.number_of_nodes()
            print self.g.number_of_edges()
            print nx.number_connected_components(self.g)
        #set time to 0
        self.g.graph['timestep'] = 0


    def set_thresholds(self, thresholds, covariates):

        #everyone has same thresholds
        if type(thresholds) == int:
            for node in self.g.nodes_iter():
                self.g.node[node]['threshold'] = thresholds
                self.g.node[node]['covariates'] = None
                self.g.node[node]['activated'] = 0
        
        #heterogenous thresholds but no covariates
        elif hasattr(thresholds, '__iter__') and covariates == None: 
            assert len(thresholds) == g.order(), 'OMG WRONG NUMBER OF THRESHOLDS'
            for idx, node in enumerate(self.g.nodes_iter()):
                self.g.node[node]['threshold'] = thresholds[idx]
                self.g.node[node]['covariates'] = None
                self.g.node[node]['activated'] = 0

        #heterogenous thresholds with covariates
        #most common use case
        elif hasattr(thresholds, '__iter__') and covariates != None: 
            assert len(thresholds) == self.g.order(), 'OMG WRONG NUMBER OF THRESHOLDS OR COVARIATES'
            for idx, node in enumerate(self.g.nodes_iter()):
                self.g.node[node]['threshold'] = thresholds[idx]
                self.g.node[node]['covariates'] = covariates[idx]
                self.g.node[node]['activated'] = 0


    def seed_nodes(self, seed_fraction):
        for node in self.g.nodes_iter():
            rndm = random()
            if rndm >= 1 - seed_fraction:
                self.g.node[node]['activated'] = 1
            else:
                self.g.node[node]['activated'] = 0


    @timer
    def broadcast_update(self):
        '''
        broadcast_update rule for the graph
        Call once to perform one discrete-timestep iteration
        '''

        nodes_last_round = None

        while nodes_last_round != 0:
            nodes_last_round = 0
            new_graph = deepcopy(self.g)
            new_graph.graph['timestep'] += 1

            #print new_graph.size()
            #print new_graph.order()

            for ego in self.g.nodes_iter():
                #print new_graph.node[ego]
                #if new_graph.graph['timestep'] == 1 and self.g.node[ego]['activated'] == 1:
                #    pass
                    #print self.g.node[ego]
                    #print 'passing'
                    #no need to evaluate if already activated
                if self.g.node[ego]['activated'] == 1:
                    continue
                activated_alters = 0
                for alter in new_graph[ego]:
                    activated_alters += self.g.node[alter]['activated']
                if activated_alters >= self.g.node[ego]['threshold']:
                    nodes_last_round += 1
                    new_graph.node[ego]['activated'] = 1
                if new_graph.node[ego]['covariates'] != None:
                    self.add_node_to_df(ego, new_graph.node[ego]['activated'], activated_alters, new_graph.graph['timestep'], new_graph.node[ego]['threshold'], new_graph.node[ego]['covariates'])
                else:
                    self.add_node_to_df(ego, new_graph.node[ego]['activated'], activated_alters, new_graph.graph['timestep'], new_graph.node[ego]['threshold'])
            self.g = new_graph
            print 'finished iteration; {} activations'.format(nodes_last_round)


    @timer
    def targeted_update(self):
        '''
        message passing model

        pick a random activated ego to RECIEVE a message

        really simple: pick an unactivated node, pick an activated alter, increment count by 1, store who sent message on node
        '''
        #early adopters have threshold < 0
        activated_set = set()
        all_nodes = set(self.g.nodes())

        for ego in self.g.nodes_iter():
            if self.g.node[ego]['threshold'] < 0:
                self.g.node[ego]['activated'] = 1
                activated_set.add(ego)
                if self.g.node[ego]['covariates'] != None:
                    self.add_node_to_df(ego, self.g.node[ego]['activated'], 0, None, self.g.node[ego]['threshold'], self.g.node[ego]['covariates'])
                else:
                    self.add_node_to_df(ego, self.g.node[ego]['activated'], 0, None, self.g.node[ego]['threshold'])

        #assumes we'll stop eventually
        rounds_with_no_progress = 0

        while len(activated_set) < self.g.number_of_nodes():
            unactivated = all_nodes - activated_set
            #randomly choose an ego
            ego = choice(tuple(unactivated))
            alter_set = set(self.g[ego].keys())
            prev_messengers = self.g.node[ego].get('prev messengers', set())
            activated_alters = (activated_set & alter_set) - prev_messengers
            if len(activated_alters) == 0:
                rounds_with_no_progress += 1
                if rounds_with_no_progress == 10000:
                    print 'break!'
                    break
                else:
                    continue

            #random messenger
            messenger = choice(tuple(activated_alters))
            if 'prev messengers' not in self.g.node[ego]:
                self.g.node[ego]['prev messengers'] = set()
            if 'activated alters' not in self.g.node[ego]:
                self.g.node[ego]['activated alters'] = 0

            self.g.node[ego]['prev messengers'].add(messenger)
            self.g.node[ego]['activated alters'] += 1

            if self.g.node[ego]['activated alters'] >= self.g.node[ego]['threshold']:
                activated_set.add(ego)
                rounds_with_no_progress = 0
                self.g.node[ego]['activated'] = 1
                if self.g.node[ego]['covariates'] != None:
                    self.add_node_to_df(ego, self.g.node[ego]['activated'], len(self.g.node[ego]['prev messengers']), None, self.g.node[ego]['threshold'], self.g.node[ego]['covariates'])
                else:
                    self.add_node_to_df(ego, self.g.node[ego]['activated'], len(self.g.node[ego]['prev messengers']), None, self.g.node[ego]['threshold'])
            #if len(activated_set) % 100 == 0:
            #    print 'there are {} activated nodes'.format(len(activated_set))
        print len(activated_set)


    def add_node_to_df(self, ego, activated, activated_alters, timestep, true_threshold, covariates=None):
        rows, cols = self.df.shape
        to_add = [ego, activated, activated_alters, timestep, true_threshold]
        if covariates:
            for cov in self.covariate_names: #again, alphabetical order
                to_add.append(covariates[cov])
        self.df.loc[rows + 1] = to_add


    def __call__(self, num_iter=10, broadcast=True):
        if broadcast:
            self.broadcast_update()
        else:
            self.targeted_update()


    @timer
    def correctly_prune_df(self):
        '''
        throw out all but last unactivated and first activated

        for each i, max(t) : y = 0
        for each i, min(t) : y = 1

        keep only if diffrence in alters == 1

        this is the most restrictive way of doing this
        we can approx it by giving (after - before / 2), where n is the jump
        '''
        df = self.df
        pruned_df = pd.DataFrame(columns=tuple(list(df.columns) + ['observed']))
        indexes = df['ego']

        seeds = 0
        adopters = 0

        for ego in set(indexes):
            unactivated_df = df.loc[(df['ego'] == ego) & (df['activated'] == 0)]
            activated_df = df.loc[(df['ego'] == ego) & (df['activated'] == 1)]

            #for seeds, skip
            #if unactivated_df.shape[0] == 0 or activated_df.shape[0] == 0:
            #    continue

            #don't skip seeds! need for correction
            #don't think we can say anything about non-adopters though?
            if activated_df.shape[0] == 0:
                #print unactivated_df
                continue
            elif unactivated_df.shape[0] == 0:
                #for early adopters
                min_time_activated = min(activated_df['timestep'])
                min_activated_row = df.loc[(df['ego'] == ego) & (df['activated'] == 1) & (df['timestep'] == min_time_activated)]
                row_as_matrix = min_activated_row.as_matrix()
                row_as_matrix = np.append(row_as_matrix[0], 1)
                #print row_as_matrix
                seeds += 1
            else:
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
                    row_as_matrix = min_activated_row.as_matrix()
                    row_as_matrix = np.append(row_as_matrix[0], 0)

                    #try averaging past two
                    #diff = (min_activated_row['activated alters'].iloc[0] - max_unactivated_row['activated alters'].iloc[0])/float(2)
                    #row_as_matrix = min_activated_row.as_matrix()
                    #col_num = list(min_activated_row.columns).index('activated alters')
                    #row_as_matrix[0][col_num] = diff
                    adopters += 1
                elif min_activated_row['activated alters'].iloc[0] - max_unactivated_row['activated alters'].iloc[0] == 1:
                    #observed is 1
                    row_as_matrix = min_activated_row.as_matrix()
                    row_as_matrix = np.append(row_as_matrix[0], 1)
                    adopters += 1
            rows, cols = pruned_df.shape
            pruned_df.loc[rows + 1] = row_as_matrix
        self.pruned_exists = True
        self.pruned_df = pruned_df


    def OLS(self, correct=True):
        if correct:
            if self.pruned_exists == False:
                self.correctly_prune_df()
        else:
            df = self.incorrectly_prune_df()

        df = self.pruned_df.loc[(self.pruned_df['observed'] == 1)]
        y = df['activated alters']
        covariates = df[self.covariate_names]
        constant = pd.DataFrame([1]*covariates.shape[0], index=covariates.index)
        X = constant.join(covariates)
        y = y.as_matrix()
        X = X.as_matrix()

        #print type(y)
        #print X
        #h = X * la.inv(X.T * X) * X.T
        beta = np.dot(np.dot(la.inv(np.dot(X.T, X)), X.T),y)
        return beta

    def heckman(self):
        #probit part
        if self.pruned_exists == False:
            self.correctly_prune_df()

        pruned = self.pruned_df.convert_objects(convert_numeric=True)

        data_endog = pruned[['observed']]
        data_exog = sm.add_constant(pruned[self.covariate_names + ['timestep']])
        probit = sm.Probit(data_endog, data_exog)
        fitted = probit.fit()
        self.fitted = fitted
        fv = fitted.fittedvalues
        #res_dev = np.sqrt(np.var(fitted.resid))
        #z = np.array([-x/res_dev for x in fv])
        #fv_var = np.array([norm.pdf(x)/norm.cdf(-x) for x in z])
        inv_mills = np.array([norm.pdf(x)/norm.cdf(-x) for x in fv])
        inv_mills = np.matrix(inv_mills).T
        pruned['inv mills'] = inv_mills

        #ols part
        observed = pruned.loc[(pruned['observed'] == 1)]

        y = observed['activated alters']
        covariates = observed[self.covariate_names + ['inv mills']]
        constant = pd.DataFrame([1]*covariates.shape[0], index=covariates.index)
        X = constant.join(covariates)
        inv_mills_ratio = 0
        y = y.as_matrix()
        X = X.as_matrix()

        #print type(y)
        #print X
        #h = X * la.inv(X.T * X) * X.T
        beta = np.dot(np.dot(la.inv(np.dot(X.T, X)), X.T),y)
        return beta


    @staticmethod
    def gen_integer_thresholds(num_nodes=1000, default=1, **kwargs):
        '''
        can be called without instantiating the class
        should be called before making an instance, you can then pass the resulting thresholds and covariates to the instance

        default is the 'baseline', or constant value in the regression

        kwargs should be of the form ('covariate name': (beta value, distribution type))
            distribution type should be 'uniform', 'gauss', or 'binary'

        actual individual-level variables are pulled from a gauss(0,1), a uniform(0,1), or a binary 0 or 1

        need to add the fractional threshold case
        '''
        thresholds = []
        covariates = []

        print kwargs

        for i in xrange(num_nodes):
            individual_covariates = {}
            individual_threshold = default

            for k,v in kwargs.items():
                name = k
                beta = v[0]
                distribution = v[1]
                if distribution == 'gauss':
                    individual_covariates[name] = gauss(0,1)
                elif distribution == 'uniform':
                    individual_covariates[name] = random()
                elif distribution == 'binary':
                    individual_covariates[name] = randint(0,1)
            
                #add the effect of manipulation here
                individual_threshold += beta * individual_covariates[name]
            error = gauss(0,1)
            individual_threshold += error

            thresholds.append(individual_threshold) 
            covariates.append(individual_covariates)

        return thresholds, covariates


    @staticmethod
    def gen_fractional_thresholds(num_nodes=1000, default=1, **kwargs):
        '''
        can be called without instantiating the class
        should be called before making an instance, you can then pass the resulting thresholds and covariates to the instance

        default is the 'baseline', or constant value in the regression

        kwargs should be of the form ('covariate name': (beta value, distribution type))
            distribution type should be 'uniform', 'gauss', or 'binary'

        actual individual-level variables are pulled from a gauss(0,1), a uniform(0,1), or a binary 0 or 1

        need to add the fractional threshold case
        '''
        thresholds = []
        covariates = []

        print kwargs

        for i in xrange(num_nodes):
            individual_covariates = {}
            individual_threshold = default

            for k,v in kwargs.items():
                name = k
                beta = v[0]
                distribution = v[1]
                if distribution == 'gauss':
                    individual_covariates[name] = gauss(0,1)
                elif distribution == 'uniform':
                    individual_covariates[name] = random()
                elif distribution == 'binary':
                    individual_covariates[name] = randint(0,1)
            
                #add the effect of manipulation here
                individual_threshold += beta * individual_covariates[name]
            error = gauss(0,1)
            individual_threshold += error

            thresholds.append(individual_threshold) 
            covariates.append(individual_covariates)

        return thresholds, covariates


if __name__ == '__main__':
    basepath = '/Users/g/Google Drive/Fall 2014/diffusion/thresholds/data/'

    thresholds, covariates = ThresholdGraph.gen_integer_thresholds(num_nodes=10000, default=5, var1=(3, 'gauss'), var2=(3, 'gauss'), bin_var1=(-1,'binary'))

    '''
    #broadcast regular
    tg = ThresholdGraph(num_nodes=10000, neighbors=15, thresholds=thresholds, covariates=covariates, rand_graph_type='regular')
    tg(40)
    tg.correctly_prune_df()
    pruned_df = tg.pruned_df
    pruned_df.to_csv(basepath + 'broadcast_regular_output.csv')

    #broadcast poisson
    tg = ThresholdGraph(num_nodes=10000, neighbors=15, thresholds=thresholds, covariates=covariates, rand_graph_type='poisson')
    tg(40)
    tg.correctly_prune_df()
    pruned_df = tg.pruned_df
    pruned_df.to_csv(basepath + 'broadcast_poisson_output.csv')

    #broadcast watts strogatz
    tg = ThresholdGraph(num_nodes=10000, neighbors=15, thresholds=thresholds, covariates=covariates, rand_graph_type='watts-strogatz')
    tg(40)
    tg.correctly_prune_df()
    pruned_df = tg.pruned_df
    pruned_df.to_csv(basepath + 'broadcast_watts_strogatz_output.csv')

    #broadcast power law
    tg = ThresholdGraph(num_nodes=10000, neighbors=15, thresholds=thresholds, covariates=covariates, rand_graph_type='power law')
    tg(40)
    tg.correctly_prune_df()
    pruned_df = tg.pruned_df
    pruned_df.to_csv(basepath + 'broadcast_power_law_output.csv')

    '''
    #targeted regular
    tg = ThresholdGraph(num_nodes=10000, neighbors=15, thresholds=thresholds, covariates=covariates, rand_graph_type='regular')
    tg(broadcast=False)
    pruned_df = tg.df
    pruned_df.to_csv(basepath + 'targeted_regular_output.csv')

    #targeted poisson
    tg = ThresholdGraph(num_nodes=10000, neighbors=15, thresholds=thresholds, covariates=covariates, rand_graph_type='poisson')
    tg(broadcast=False)
    pruned_df = tg.df
    pruned_df.to_csv(basepath + 'targeted_poisson_output.csv')

    #targeted regular
    tg = ThresholdGraph(num_nodes=10000, neighbors=15, thresholds=thresholds, covariates=covariates, rand_graph_type='watts-strogatz')
    tg(broadcast=False)
    pruned_df = tg.df
    pruned_df.to_csv(basepath + 'targeted_watts_strogatz_output.csv')

    #targeted regular
    tg = ThresholdGraph(num_nodes=10000, neighbors=15, thresholds=thresholds, covariates=covariates, rand_graph_type='power law')
    tg(broadcast=False)
    pruned_df = tg.df
    pruned_df.to_csv(basepath + 'targeted_power_law_output.csv')
