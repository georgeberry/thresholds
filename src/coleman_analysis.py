import networkx as nx
import pandas as pd
import numpy as np

"""
We do a reanalysis of the Coleman medical innovation dataset found here:
    http://moreno.ss.uci.edu/data.html#ckm

As seen from the documentation, there are 3 types of networks in the dataset
    Advice
    Discussion
    Friend

They're in this order in the dataset

We also have a data-matrix with some variables

The plan here is to use Advice and Discussion networks together, following Burt

To implement our threshold condition here we use the following rule:
    We measure the threshold for individuals with exactly 1 neighbor adopting in the month prior to first adoption

In other words, we can label nodes with thresholds and apply a simple rule:
    Threshold is correctly measured if exactly 1 neighbor adopted in period prior to ego adoption
    In this case, threshold is the number of neighbors that adopted before ego

We can then get the expsoure-at-activation for all nodes, plus a variable indicating whether we correctly measure or not

Want to output a data frame of the original variables plus exposure at activation and correct measurement status
"""

ADJ_CSV_PATH = '../data/coleman/adj.csv'
VAR_CSV_PATH = '../data/coleman/var.csv'
OUT_CSV_PATH = '../data/coleman/output.csv'

MAX_LAG_TIME = 20

df = pd.read_csv(VAR_CSV_PATH)

replace_dict = {
    'adoption date': {98: np.nan, 99: np.nan},
    'med_sch_yr': {9: np.nan},
    'meetings': {9: np.nan},
    'jours': {9: np.nan},
    'free_time': {9: np.nan},
    'discuss': {9: np.nan},
    'clubs': {9: np.nan},
    'friends': {9: np.nan},
    'community': {9: np.nan},
    'patients': {9: np.nan},
    'proximity': {9: np.nan},
    'specialty': {9: np.nan},
}
df = df.replace(to_replace=replace_dict)
print(df)

adj = np.genfromtxt(ADJ_CSV_PATH, delimiter=",")

advice = adj[0:246,]
discussion = adj[246:492,]
friend = adj[492:738,]
combined = advice + discussion

g = nx.from_numpy_matrix(combined)

for ego, data in g.nodes_iter(data=True):
    data['adoption date'] = df.loc[ego, 'adoption date']

d = {} #{ego : {'exposure at adoption': int, 'measured': bool}}

# TODO: need to handle never-adopters
for ego, data in g.nodes_iter(data=True):
    ego_adoption_date = data['adoption date']
    if np.isnan(ego_adoption_date):
        # if ego never adopted
        # record and proceed to next ego
        d[ego] = {
            'exposure at adoption': np.nan,
            'correctly measured': np.nan,
            'last period activations': np.nan,
            'activation delay': np.nan,
        }
        continue
    ego_g = nx.ego_graph(g, ego, center=False)
    n_active = 0
    n_active_in_prev_periods = {}
    for alter, a_data in ego_g.nodes_iter(data=True):
        a_adoption_date = a_data['adoption date']
        if a_adoption_date == 98 or a_adoption_date == 99:
            # don't add non-adopting alters to record of alter adoptions
            continue
        if a_adoption_date < ego_adoption_date:
            n_active += 1
            if a_adoption_date not in n_active_in_prev_periods:
                n_active_in_prev_periods[a_adoption_date] = 0
            n_active_in_prev_periods[a_adoption_date] += 1
    # early adopters
    if len(n_active_in_prev_periods) == 0:
        correctly_measured = 1
        last_period_activations = 0
        lag_time = 0
    lag_time = 0
    # go reverse-chron from ego adoption date - 1
    # if exactly 1 alter adopted in the prev month, that's the threshold
    # accept up to MAX_LAG_TIME months with 0 adoptions
    # for instance, if MAX_LAG_TIME = 2
    #   then we consider up to 3 months ago
    #   if there's a single adoption in one of these 3 months, and
    #   if it's the most recent adoption, then we call that the threshold
    for period in reversed(range(1, int(ego_adoption_date))):
        if period not in n_active_in_prev_periods:
            # if a previous period had 0 activations
            lag_time += 1
            continue
        if n_active_in_prev_periods[period] == 1 and lag_time <= MAX_LAG_TIME:
            correctly_measured = 1
            last_period_activations = 1
            break
        elif n_active_in_prev_periods[period] > 0 or lag_time > MAX_LAG_TIME:
            correctly_measured = 0
            last_period_activations = n_active_in_prev_periods[period]
            break
        else:
            raise ValueError
    d[ego] = {
        'exposure at adoption': n_active,
        'correctly measured': correctly_measured,
        'last period activations': last_period_activations,
        'activation delay': lag_time,
    }

measured_df = pd.DataFrame(d).transpose()

combined_df = pd.concat([df, measured_df], axis=1)

combined_df.to_csv(OUT_CSV_PATH)
