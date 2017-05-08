import numpy as np
import networkx as nx
import pandas as pd
from copy import deepcopy

"""
Analysis of Coleman et al. (1966), as compiled by Burt and retrieved
here: http://moreno.ss.uci.edu/data.html#ckm

Data is three 246^2 matrices with a 9 line header
These correspond to relationships (in order):
- "ADVICE"
- "DISCUSSION"
- "FRIEND"

There is a 246x13 list of variables with an 18 row header
- "city"
- "adoption date" (18 and 98 mean never)
- "med_sch_yr"
- "meetings"
- "jours"
- "free_time"
- "discuss"
- "clubs"
- "friends"
- "community"
- "patients"
- "proximity"
- "specialty"

Strategy is to read the 738x246 into numpy and then break it up there by row
slicing

Analysis:
- Assume updates are like this: at beginning of the time step, nodes activate,
  and then inactive nodes nodes update.
- How many mismeasurements are there?
- Go through each adoption date from 1 to 17
-
"""

ADJ_PATH = 'coleman_adj_mat.txt'
VAR_PATH = 'coleman_vars.txt'

#### Read networks #############################################################

adj_mat_list = []

with open(ADJ_PATH, 'r') as infile:
    for idx, line in enumerate(infile):
        if idx < 9:
            continue
        row = [int(x) for x in line.strip().split()]
        adj_mat_list.append(row)

adj_mat_all = np.array(adj_mat_list)

adj_mat_advice = adj_mat_all[0:246, :]
adj_mat_discussion = adj_mat_all[246:492, :]
adj_mat_friend = adj_mat_all[492:738, :]

g_advice = nx.Graph(adj_mat_advice)
g_advice.graph['name'] = 'advice'
g_discuss = nx.Graph(adj_mat_discussion)
g_discuss.graph['name'] = 'discuss'
g_friend = nx.Graph(adj_mat_friend)
g_friend.graph['name'] = 'friend'

#### Read variables ############################################################

colnames = [
    'city',
    'adoption_date',
    'med_sch_yr',
    'meetings',
    'jours',
    'free_time',
    'discuss',
    'clubs',
    'friends',
    'community',
    'patients',
    'proximity',
    'specialty',
]
var_list = []

with open(VAR_PATH, 'r') as infile:
    for idx, line in enumerate(infile):
        if idx < 18:
            continue
        row = [int(x) for x in line.strip().split()]
        dict_row = {colnames[idx]: val for idx, val in enumerate(row)}
        # add three bookkeeping cols
        dict_row['active'] = 0
        dict_row['exposure_history'] = []
        dict_row['exposure_at_activation'] = 0
        var_list.append(dict_row)

#### Data on graphs ############################################################

for idx, dict_row in enumerate(var_list):
    g_advice.node[idx] = deepcopy(dict_row)
    g_discuss.node[idx] = deepcopy(dict_row)
    g_friend.node[idx] = deepcopy(dict_row)

graphs = [g_advice, g_discuss, g_friend]

#### Iteration #################################################################

"""
Activate nodes that activate at t, then record updates for everyone else
"""
for t in range(1, 18):
    for g in graphs:
        # activate and record
        to_activate = []  # simulateous updating
        for n, attr in g.nodes_iter(data=True):
            if attr['adoption_date'] == t:
                to_activate.append(n)
                s = nx.ego_graph(g, n)
                s.remove_node(n)  # delete ego
                attr['exposure_at_activation'] = sum(
                    [s_attr['active'] for s_n, s_attr in s.nodes_iter(data=True)]
                )
                attr['exposure_history'].append(
                    attr['exposure_at_activation']
                )
        # actually activate them
        for idx in to_activate:
            g.node[idx]['active'] = 1
        # update nodes and record
        for n, attr in g.nodes_iter(data=True):
            if attr['active'] == 0:
                s = nx.ego_graph(g, n)
                attr['exposure_history'].append(sum(
                    [s_attr['active'] for s_n, s_attr in s.nodes_iter(data=True)]
                ))

for g in graphs:
    for n, attr in g.nodes_iter(data=True):
        exposure_history = attr.pop('exposure_history')  # remove it
        exposure_history.reverse()  # in place
        exposure_at_activation = exposure_history[0]
        for e in exposure_history:
            if e < exposure_at_activation:
                attr['interval'] = exposure_at_activation - e
                break

advice_df = pd.DataFrame(
    [g_advice.node[x] for x in range(g_advice.number_of_nodes())]
)
discuss_df = pd.DataFrame(
    [g_discuss.node[x] for x in range(g_discuss.number_of_nodes())]
)
friend_df = pd.DataFrame(
    [g_friend.node[x] for x in range(g_friend.number_of_nodes())]
)

print(sum(advice_df.interval > 1))
print(sum(discuss_df.interval > 1))
print(sum(friend_df.interval > 1))

#### Analysis ##################################################################
