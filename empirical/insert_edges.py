import json
from helpers import psql_connect, psql_insert_many

with open('config.json', 'r') as f:
    j = json.load(f)
    EDGELIST_FILE = j['edgelist']

# Insert edges #

db = psql_connect()

count = 0
edge_data = []

print('Beginning edge insertion.')

with open(EDGELIST_FILE, 'r') as f:
    for line in f:
        n1, n2 = [int(x) for x in line.strip('\n').split('\t')]
        edge_data.append((n1, n2))
        edge_data.append((n2, n1))
        count += 2
        # every millionth item insert and reset
        if count % 1000000 == 0:
            print("Inserting {} edges!".format(count))
            psql_insert_many(
                db, 'Edges', edge_data, ignore_conflict=True
            )
            edge_data = []
    psql_insert_many(db, 'Edges', edge_data, ignore_conflict=True)
