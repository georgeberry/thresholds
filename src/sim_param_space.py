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

EMPIRICAL_OUTPUT_FILE = '../data/empirical_param_space.json'
SIM_OUTPUT_FILE = '../data/made_up_param_space.json'

EMPIRICAL_VAR_NAMES = set([
    'student',
    'gender',
    'major',
    'major2',
    'dorm',
    'year',
    'high_school',
])

SIM_VAR_NAMES = set([
    'var1',
    'var2',
    'var3',
])

ERROR_SDS = [
    0.5,
    0.8,
    1.0,
    1.5,
    2.0,
]

NORMAL_SDS = [
    1.0,
]

BINOMIAL_MEANS = [
    0.5,
]

CONSTANT = 5

COEFFICIENTS = [
    3.0,
]

# can also be 'binomial'
VAR_TYPES = [
    'normal',
]

MAX_VARS = 1

## functions ##

def choose_empirical_vars(n_vars):
    for vnames in combinations(EMPIRICAL_VAR_NAMES, n_vars):
        yield ['constant'] + list(vnames) + ['epsilon']

def create_empirical_means(dists):
    means = [None] * len(dists)
    means[-1] = 0
    return means


def create_empirical_dist_dicts(max_vars):
    """
    """
    for n_vars in range(1, max_vars + 1):
        for vnames in choose_empirical_vars(n_vars):
            for coefs in create_coefs(vnames):
                means = create_empirical_means(vnames)
                for sds in create_sds(vnames):
                    yield merge_empirical(vnames, coefs, means, sds)

def merge_empirical(vnames, coefs, means, sds):
    dist_dict = {}
    for idx in range(len(vnames)):
        name = vnames[idx]
        coef = coefs[idx]
        mean = means[idx]
        sd = sds[idx]
        dist_dict[name] = {
            'distribution': name,
            'mean': mean,
            'sd': sd,
            'coefficient': coef,
        }
    return dist_dict


def all_indicies(val, iterable):
    indicies = []
    counter = 0
    for i in iterable:
        if i == val:
            indicies.append(counter)
        counter += 1
    return indicies

def create_dists(n_vars):
    """
    add constant to beginning and epsilon to end
    """
    for dists in combinations_with_replacement(VAR_TYPES, n_vars):
        yield ['constant'] + list(dists) + ['epsilon']

def create_coefs(dists):
    """
    Cycle through coefficient combinations
    """
    n_vars = len(dists)
    for coefs in combinations_with_replacement(COEFFICIENTS, n_vars):
        coefs = list(coefs)
        coefs[-1] = None
        coefs[0] = CONSTANT
        yield coefs

def create_means(dists):
    """
    Means for all non-binary variables are 0, except constant which is None
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
        for sds_comb in combinations_with_replacement(NORMAL_SDS, num_norm):
            sds_comb = list(sds_comb)
            norm_idx = all_indicies('normal', dists)
            idx_counter = 0
            for idx in norm_idx:
                sds[idx] = sds_comb[idx_counter]
                idx_counter += 1
            for error_sd in ERROR_SDS:
                sds[-1] = error_sd
                yield sds
    else:
        for error_sd in ERROR_SDS:
            sds[-1] = error_sd
            yield sds


def create_sim_dist_dicts(max_vars):
    """
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
                        yield merge(dists, coefs, means, sds)


def merge(dists, coefs, means, sds):
    dist_dict = {}
    for idx in range(len(dists)):
        dist = dists[idx]
        coef = coefs[idx]
        mean = means[idx]
        sd = sds[idx]
        if dist in {'constant', 'epsilon'}:
            dist_dict[dist] = {
                'distribution': dist,
                'mean': mean,
                'sd': sd,
                'coefficient': coef,
            }
        else:
            name = 'var' + str(idx)
            dist_dict[name] = {
                'distribution': dist,
                'mean': mean,
                'sd': sd,
                'coefficient': coef,
            }
    return dist_dict


## run program ##

if __name__ == '__main__':
    with open(SIM_OUTPUT_FILE, 'wb') as f:
        for dist_dict in create_sim_dist_dicts(MAX_VARS):
            j = json.dumps(dist_dict) + '\n'
            f.write(j)
    with open(EMPIRICAL_OUTPUT_FILE, 'wb') as f:
        for dist_dict in create_empirical_dist_dicts(MAX_VARS):
            j = json.dumps(dist_dict) + '\n'
            f.write(j)
