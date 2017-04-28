import sys
import bz2
import logging
import ujson as json
from helpers import create_timestamp
from helpers import psql_connect, psql_insert_many

"""
bz2 open one file, insert to the Tweets table

Tweets table looks like this:
    src bigint
    tid varchar(20)
    created_at timestamp
    hashtag varchar(140)

To test:
    python insert_tweets.py /Volumes/Vostok/class/twitter_data/thresholds/part-00000.tsv.bz2
"""


def BatchYielder(object):
    """
    Inputs:
        fname: tsv.bz2 file to open
        batch_size: integer representing number of elements to yield
    Outputs:
        (row1, row2, row3, ... row_batch_size)
        each row is a tuple that fits into the Tweets table schema given above
    """

    def __init__(self, fname, batch_size=50000):
        self.fname = fname
        self.batch_size = batch_size
        self.count = 0
        self.cache = ''
        self.current_batch = []

    def process_full_line(self, uid, tstamp_str, tid, text, htag_str):
        """
        If we know we have all 5 elements, process them and potentially yield
        """
        timestsamp = create_timestamp(tstamp_str)
        if len(htag_str) > 2:
            hashtags = json.loads(htag_str)
        else:
            hashtags = [None]
        self.count += 1
        for hashtag in hashtags:
            self.current_batch.append((
                uid,
                tid,
                timestsamp,
                hashtag,
            ))

    def __iter__(self):
        with bz2.open(self.fname, 'rt') as infile:
            for line in f:
                # if cache > 0, try to tab split
                # else add to cache
                if len(self.cache) > 0:
                    try:
                        uid, tstamp_str, tid, text, htag_str = \
                            self.cache.split('\t')
                        self.process_full_line(
                            uid,
                            tstamp_str,
                            tid,
                            text,
                            htag_str,
                        )
                        self.cache = b''
                    except ValueError:
                        self.cache += line
                # if len(cache) == 0
                # try to split
                else:
                    try:
                        uid, tstamp_str, tid, text, htag_str = line.split('\t')
                        self.process_full_line(
                            uid,
                            tstamp_str,
                            tid,
                            text,
                            htag_str,
                        )
                    except ValueError:
                        self.cache += line
                # yield here
                if len(self.current_batch) >= self.batch_size:
                    print('Yielded {}!'.format(self.count))
                    yield self.current_batch
                    self.current_batch = []
            else:
                yield self.current_batch

if __name__ == '__main__':
    db = psql_connect()
    table = 'Tweets'
    fname = sys.argv[1]
    by = BatchYielder(fname)
    for batch in by:
        pass
        # psql_insert_many(db, table, batch)
