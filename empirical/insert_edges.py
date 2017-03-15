import json
from helpers import psql_connect, psql_insert_many

with open('config.json', 'r') as f:
    j = json.load(f)
    EDGELIST_FILE = j['edgelist']

# Insert edges #

db = psql_connect()

edge_data = set()

print('Reading edges.')

with open(EDGELIST_FILE, 'r') as f:
    for line in f:
        n1, n2 = [int(x) for x in line.strip('\n').split('\t')]
        edge_data.add((n1, n2))
        edge_data.add((n2, n1))

print('Beginning edge insertion.')

count = 0
edge_list = []

for edge in edge_data:
    edge_list.append(edge)
    count += 1
    # every millionth item insert and reset
    if count >= 1000000:
        print("Inserting {} edges!".format(count))
        psql_insert_many(db, 'Edges', edge_list)
        edge_list = []
psql_insert_many(db, 'Edges', edge_list)
