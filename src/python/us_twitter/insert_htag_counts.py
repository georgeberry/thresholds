import collections as coll
import ujson as json
import glob
import bz2
import re
import sys
from helpers import TW_DATE_FMT, PS_DATE_FMT, create_timestamp



# List of tuples, (htag, count)
ht_data = []
with open(HTAG_COUNT_FILE, 'r') as f:
    for line in f:
        htag, count = line.strip('\n').split('\t')
        ht_data.append((str(htag), int(count)))
print('Here\'s what the data looks like')
print(ht_data[:10])
psql_insert_many(db, 'Hashtags', ht_data)
print('Inserted hashtags successfully!')
del ht_data
