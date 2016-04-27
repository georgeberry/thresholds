"""
Similar to sim_param_space.py

A few modifications:
    1) Only variable-level param is the error term sd
    2)

List of empirical vars:
    'student'
    'gender'
    'major'
    'major2'
    'dorm'
    'year'
    'high_school'

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
"""
import json
from itertools import combinations, combinations_with_replacement

EMPIRICAL_OUTPUT_FILE = '../data/empirical_param_space.json'
SIM_OUTPUT_FILE = '../data/made_up_param_space.json'

EMPIRICAL_VARS_TO_USE = [
    'gender',
]

ERROR_SDS = [
    0.5,
    0.8,
    1.0,
    1.5,
    2.0,
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

def create_thresholds():
    all_vars = ['constant'] + EMPIRICAL_VARS_TO_USE + ['epsilon']
    for var in all_vars:
        if var == 'constant':

        elif var == 'epsilon':

        else:
