import sys
import json
import datetime as dt
from helpers import TW_DATE_FMT, PS_DATE_FMT, create_timestamp
from helpers import psql_connect, psql_insert_many

"""
Parallelize this

find /Volumes/Starbuck/class/twitter_data/jq_filtered/part-000**.bz2.tsv -print0 | xargs -0 -n1 -P1 -- bash -c 'python3 first_use_pure_python.py "$0"'
"""

FNAME = sys.argv[1]

# (uid, htag): (first_use, tid)
first_use_dict = {}

with open(FNAME, 'r') as f:
    for line in f:
        hashtag, uid, tid, created_at = line.strip().split('\t')
        created_at = dt.datetime.strptime(created_at, TW_DATE_FMT)
        if hashtag == '' or uid == '' or tid == '' or created_at == '':
            continue
        key = (uid, hashtag)
        val = (created_at, tid)
        if key not in first_use_dict:
            first_use_dict[key] = val
        else:
            prev_created_at, tid = first_use_dict[key]
            if created_at < prev_created_at:
                first_use_dict[key] = val

db = psql_connect()

count = 0
to_write = []

# column ordering: uid, tid, created_at, hashtag
for key, val in first_use_dict.items():
    uid, hashtag = key
    created_at, tid = val
    created_at = created_at.strftime(PS_DATE_FMT)[:-2]
    tup = (uid, tid, created_at, hashtag)
    to_write.append(tup)
    count += 1
    if count > 100000:
        psql_insert_many(db, "NeighborTags", to_write)
        print('Inserted another 100k!')
        to_write = []
        count = 0

psql_insert_many(db, "NeighborTags", to_write)
to_write = []

print('Finished file {}!'.format(FNAME))
