import sys
import bz2
import logging
import ujson as json
from helpers import create_timestamp
from helpers import psql_connect, psql_setup, psql_insert_many

"""
bz2 open one file, insert to the Tweets table

Tweets table looks like this:
    src bigint
    tid varchar(20)
    created_at timestamp
    hashtag varchar(140)
"""

def yield_batches(fname, batch_size=50000):
    """
    Inputs:
        fname: tsv.bz2 file to open
        batch_size: integer representing number of elements to yield
    Outputs:
        (row1, row2, row3, ... row_batch_size)
        each row is a tuple that fits into the Tweets table schema given above
    """
    current_batch = []
    with bz2.open(fname, 'r') as f:
        for line in f:
            uid, tstamp_str, tid, text, htag_str = line.split('\t')
            timestsamp = create_timestamp(created_at)
            if len(htag_str) > 2:
                hashtags = json.loads(htag_str)
            else:
                hashtags = [None]
            for hashtag in hashtags:
                current_batch.append((
                    uid,
                    tid,
                    timestsamp,
                    hashtag,
                ))
                if len(current_batch) >= batch_size:
                    print('Yielding {}!'.format(batch_size))
                    yield current_batch
                    current_batch = []
        else:
            if len(current_batch) > 0:
                yield current_batch

if __name__ == '__main__':
    db = psql_connect()
    table = 'Tweets'
    fname = sys.argv[1]
    for batch in yield_batches(fname):
        psql_insert_many(db, table, batch)
