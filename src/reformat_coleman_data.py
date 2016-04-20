import re

"""
Go from shitty .dat to cool .csv
"""

ADJ_DAT_PATH = '../data/coleman/ckm.dat.txt'
VAR_DAT_PATH = '../data/coleman/attributes.dat.txt'

ADJ_CSV_PATH = '../data/coleman/adj.csv'
VAR_CSV_PATH = '../data/coleman/var.csv'

with open(ADJ_DAT_PATH, 'rb') as f:
    with open(ADJ_CSV_PATH, 'wb') as g:
        for _ in xrange(9):
            print(next(f))
        for line in f:
            output_line = line.strip().replace(' ', ',') + '\n'
            g.write(output_line)

colnames = [
    "city",
    "adoption date",
    "med_sch_yr",
    "meetings",
    "jours",
    "free_time",
    "discuss",
    "clubs",
    "friends",
    "community",
    "patients",
    "proximity",
    "specialty",
]

with open(VAR_DAT_PATH, 'rb') as f:
    with open(VAR_CSV_PATH, 'wb') as g:
        for _ in xrange(18):
            print(next(f))
        col_line = ",".join(colnames) + '\n'
        g.write(col_line)
        for line in f:
            output_line = line.strip()
            output_line = re.sub(r' +', ',', output_line) + '\n'
            g.write(output_line)
