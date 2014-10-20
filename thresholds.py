import networkx as nx
import statsmodels.api as sm
import pandas as pd
import numpy as np
from numpy.random import normal, random_integers, random
from copy import deepcopy

#graph is fixed

def update_rule(graph, df):
    #updates "simultaneously" if a certain amount of people were activated last time
    old_graph = deepcopy(graph)
    new_graph = deepcopy(graph)

    new_graph.graph['wave'] += 1

    for ego in new_graph:
        activated_friends = 0

        for friend in new_graph[ego]:
            activated_friends += old_graph.node[friend]['activated']

        if activated_friends >= 1:
            new_graph.node[ego]['activated'] = 1

        add_node_to_df(df, ego, new_graph.node[ego]['activated'], activated_friends, new_graph.graph['wave'])

    return new_graph

def add_node_to_df(df, ego, activated, activated_friends, wave):
    rows, cols = df.shape

    df.loc[rows + 1] = [ego, activated, activated_friends, wave]



class ThresholdGraph:
    '''
    allows easy creation/storage/iteration/logging of various graphs with various thresholds
    '''

    def __init__(self, rand_graph_type='regular', **kwargs):
        assert rand_graph_type in {'regular', 'watts-strogatz', 'power law', 'poisson'}, 'OMG WHAT DO I DO I NEED A DIFFERENT GRAPH TYPE'

        self.action_log = pd.DataFrame(columns=('ego','activated','activated friends', 'wave', 'covariate'))

    def create_random_graph(self, neighbors, nodes):
        self.g = nx.random_regular_graph(neighbors, nodes)

    def set_thresholds(self):
        pass

    def seed_nodes(self):
        pass




#first test

#create a graph that evolves over T time periods, where the update rule is threshold and deterministic
#everyone should have E neighbors and if > Q of neighbors have adopted, they adopt
#in principle, then, we should be able to recover this with a dummy variable

g = nx.random_regular_graph(5, 100)
g.graph['wave'] = 0
for node in g.nodes_iter():
    rndm = random()
    if rndm >= 0.95:
        g.node[node]['activated'] = 1
    else:
        g.node[node]['activated'] = 0

df = pd.DataFrame(columns=('ego', 'activated', 'activated friends', 'wave'))

for _ in range(10):
    g = update_rule(g, df)

y = df['activated']
X = df['activated friends']
X = sm.add_constant(X)

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
new_df = pd.DataFrame(columns=('ego', 'activated', 'activated friends', 'wave'))
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
X = new_df['activated friends']
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