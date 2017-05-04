import logging
from helpers import psql_connect, psql_insert_many

logging.basicConfig(
    format='%(asctime)s : %(levelname)s : %(message)s',
    level=logging.INFO,
)

ALL_USERS_FILE = '/Users/Shared/all_user_ids.tsv'
EDGELIST_FILE = (
    '/Volumes/Vostok/class/twitter_data/twitter_patrick/'
    'bidirected_us_edges/US_bidirected_edgelist.ncol'
)


#### load user set #############################################################

count = 0
all_users_set = set()

with open(ALL_USERS_FILE, 'r') as infile:
    for line in infile:
        count += 1
        if count % 100000 == 0:
            logging.info('%d' % count)
        uid = line.strip()
        all_users_set.add(uid)

logging.info('user set loaded')

#### Get edges ##################################################################

count = 0
edge_set = set()

with open(EDGELIST_FILE, 'r') as infile:
    for line in infile:
        count += 1
        n1, n2 = line.split()
        if n1 in all_users_set and n2 in all_users_set:
            edge_set.add((n1, n2))
            edge_set.add((n2, n1))
        if count % 1000000 == 0:
            print('{}'.format(count))

#### Insert edges ##############################################################

db = psql_connect()

edge_batch = []

while len(edge_set) > 0:
    edge_batch.append(edge_set.pop())
    if len(edge_batch) == 1000000:
        count += 1
        logging.info('Inserting %d million edges' % count)
        psql_insert_many(db, 'Edges', edge_batch)
        edge_batch = []
psql_insert_many(db, 'Edges', edge_batch)
