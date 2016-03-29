"""
This file creates a bunch of equations that the thresholds.py file can use

Equation syntax
equation = {
    'var_1_name': {
        'distribution': 'normal',
        'mean': mean,
        'sd': sd,
        'coefficient': coefficient
    },
    'var_2_name': {
        ...
    },
    ...
}

distribution can be 'normal' or 'binomial'
'binomial' just needs a mean, not sd

just need a coefficient for the empirical vars

for the empirical graphs:
    we want to combine the categorical emprical vars with real valued (normally distributed) simulated vars

for the sim graphs:
    want to create a mixture of normal and binomial vars

"""
import json
from itertools import combinations, combinations_with_replacement

empirical_file = '../data/empirical_param_space.json' # for empirical graphs
made_up_file = '../data/made_up_param_space.json' # for sim graphs

empirical_vars = set([
    'student',
    'gender',
    'major',
    'major2',
    'dorm',
    'year',
    'high_school',
])

made_up_vars = set([
    'var1',
    'var2',
    'var3',
])

normal_means = [
    0,
]

error_means = [
    0
]

ERROR_SDS = [
    .5,
    .75,
    1,
    1.5,
]

NORMAL_SDS = [
    1,
    2,
]

BINOMIAL_MEANS = [
    .5,
]

COEFFICIENTS = [
    1,
    3,
    5,
]


VAR_TYPES = [
    'normal',
    'binomial',
]

all_vars = empirical_vars | made_up_vars

MAX_VARS = 2

## functions ##

def all_indicies(v, l):
    indicies = []
    counter = 0
    for i in l:
        if i == v:
            indicies.append(counter)
        counter += 1
    return indicies

def create_dists(n_vars):
    for dists in combinations_with_replacement(VAR_TYPES, n_vars):
        yield ['constant'] + dists + ['epsilon']

def create_coefs(dists):
    n_vars = len(dists)
    for coefs in combinations_with_replacement(COEFFICIENTS, n_vars):
        coefs[-1] = None
        yield coefs

def create_means(dists):
    """
    means for all non-binary variables are 0, except constant which is None
    """
    means = [None] + [0] * (len(dists) - 1)
    num_bin = dists.count('binomial')
    if num_bin > 0:
        bin_idx = all_indicies('binomial', dists)
        for bin_vals in combinations_with_replacement(BINOMIAL_MEANS, num_bin):
            for val in range(num_bin):
                means[bin_idx[val]] = bin_vals[val]
            yield means
    else:
        yield means

def create_sds(dists):
    sds = [None for _ in dists]
    num_norm = dists.count('normal')
    if num_norm > 0:
        for sds in combinations_with_replacement(NORMAL_SDS, num_norm):
            norm_idx = all_indicies('normal', dists)
            for val in range(num_norm):
                sds[norm_idx[val]] = sds[val]
            for error_sd in ERROR_SDS:
                sds[-1] = error_sd
                yield sds
    else:
        yield sds

def merge(dists, coefs, means, sds):
    pass

def create_distribution_dict(max_vars):
    """
    names: var names
    dists: normal or binomial
    means: var means (0 for normal)
    sds: var sds (none for binomial)
    coefs: var coefs
    """
    for n_vars in range(1, max_vars + 1):
        for dists in create_dists(n_vars):
            for coefs in create_coefs(dists):
                for means in create_means(dists):
                    for sds in create_sds(dists):
                        dist_dict = merge(dists, coefs, means, sds)

## run program ##
