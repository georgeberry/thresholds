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


# find /Volumes/Starbuck/class/twitter_data/thresholds/part-001*.bz2 -print0 | xargs -0 -n1 -P6 python3 insert_tweets.py

"""

logging.basicConfig(
    filename='/Volumes/Vostok/class/geb97/insert.log',
    format='%(asctime)s : %(levelname)s : %(message)s',
    level=logging.INFO,
)

class BatchYielder(object):
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

    def process_full_line(self, line):
        """
        If we know we have all 5 elements, process them and potentially yield
        """
        uid, tstamp_str, tid, text_plus_htag_str = line.split('\t', 3)
        text, htag_str = text_plus_htag_str.rsplit('\t', 1)
        timestamp = create_timestamp(tstamp_str)
        hashtags = json.loads(htag_str)
        if len(hashtags) == 0:
            hashtags = [None]
        self.count += 1
        if self.count % 100000 == 0:
            logging.info("Processed {} from {}".format(self.count, self.fname))
        for hashtag in hashtags:
            self.current_batch.append((
                uid,
                tid,
                timestamp,
                hashtag,
            ))

    def __iter__(self):
        """
        This looks complicated, but it's not
        We need to deal with cases where people put whitespase chars in tweets
        To do this we need to know when a line is really done
        The easiest way to do this is to see if the second element of a line is
        the date. If create_timestamp(line.split()[1]) works, then the prev
        tweet is done.
        """
        with bz2.open(self.fname, 'rt', encoding='utf8') as infile:
            # lines can have a valid beginning or not, assessed with timestamp
            for line in infile:
                valid_beginning = None
                # assess whether we have a line beginning or not
                try:
                    timestamp = create_timestamp(line.split('\t', 2)[1])
                    valid_beginning = True
                except (ValueError, IndexError, TypeError):
                    valid_beginning = False

                # save previous line
                if valid_beginning and len(self.cache) > 0:
                    try:
                        self.process_full_line(self.cache)
                        self.cache = ''
                    except:
                        logging.error(
                            'Line {} in file {} failed with error 1'.format(
                                self.count,
                                self.fname,
                            )
                        )

                # we have a line beginning
                # if we have a complete line, save it
                # if we have a partial line
                if valid_beginning:
                    try:
                        self.process_full_line(line)
                    except (ValueError, IndexError, TypeError):
                        self.cache = line

                # line intermezzo, add to cache
                if not valid_beginning and len(self.cache) > 0:
                    self.cache = ''.join([self.cache, line])

                if not valid_beginning and len(self.cache) == 0:
                    logging.error(
                        'Line {} in file {} failed with error 2'.format(
                            self.count,
                            self.fname,
                        )
                    )

                if len(self.current_batch) > self.batch_size:
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
        psql_insert_many(db, table, batch)
