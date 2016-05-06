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
        'coefficient': coefficient,
    },
    'var_2_name': {
        ...
    },
    ...
"""
import json
from constants import *

EMPIRICAL_VARS_TO_USE = [
    'gender',
]

ERROR_SDS = [
    12.0,
    15.0,
    18.0,
]

CONSTANT = [
    10.0,
    12.0,
    15.0,
]

COEFFICIENTS = [
    5.0,
    10.0,
    15.0,
]

# can also be 'binomial'
VAR_TYPES = [
    'normal',
]

MAX_VARS = 1

## functions ##

def create_eq(var, cons, coef, sd):
    eq = {
        'constant': {
            'coefficient': cons,
            'distribution': 'constant',
            'sd': None,
            'mean': None,
        },
        'epsilon': {
            'coefficient': None,
            'distribution': 'epsilon',
            'sd': sd,
            'mean': 0
        },
        var: {
            'coefficient': coef,
            'distribution': 'empirical',
            'sd': None,
            'mean': None,
        }
    }
    return eq


if __name__ == '__main__':
    with open(EMPIRICAL_PARAM_FILE, 'wb') as f:
        for var in EMPIRICAL_VARS_TO_USE:
            for cons in CONSTANT:
                for coef in COEFFICIENTS:
                    for sd in ERROR_SDS:
                        eq = create_eq(var, cons, coef, sd)
                        j = json.dumps(eq) + '\n'
                        f.write(j)
