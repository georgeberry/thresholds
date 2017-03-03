import collections as coll
import psycopg2
import ujson as json
import glob
import bz2
import re
import csv
import io
from find_users_for_tags import TW_DATE_FMT, PS_DATE_FMT, create_timestamp

"""
Plan:
    1. Get top hashtags among geolocated users (Chris)
    2. Insert these user timelines into a Tweets dict
    3. Go through all edges and add those edges to RawEdges
    4.

See schema.sql for the postgres schema
We have four tables
    Hashtags: hashtag usage counts
    Tweets: all tweets, with timestamps, mentions, and hashtags extracted
    RawEdges: all edges compiled by Patrick
    TimestampEdges:

Analysis plan:
    For each hashtag we need to look at its first use within a user, then look
    at the tweet that immediately preceeded that. This gives us a time interval
    to work with. In that interval, if exactly one neighbor activates, then
    the individual is correctly measured.

    There is probably a more efficient algorithm to do this.
    Would be great to, in one shot, get threshold and whether its measure or not.
"""

# Read from config.json, not pushed to git for privacy
# These config options should be treated as constants
with open('config.json', 'r') as f:
    j = json.load(f)
    PSQL_USR, PSQL_PWD = j['psql_usr'], j['psql_pwd']
    HTAG_COUNT_FILE = j['htag_counts']
    # TIMELINE_FOLDER =
    EDGELIST_FILE = j['edgelist']
    SUCCESS_USER_PATTERN = j['success_pattern']
    OUTFILE_NAME = j['output_file']

# Postgres functions

def psql_connect():
    db = psycopg2.connect(
        database="thresholds",
        user=PSQL_USR,
        password=PSQL_PWD,
        host="localhost",
        #port=port,
    )
    return db

def psql_setup(db):
    """
    Only need to run once, but since we don't do anything if a table exists
    you won't blow the world up running it again
    """
    with open('schema.sql', 'r') as f:
        db.cursor().execute(f.read())
        db.commit()

def psql_insert_many(db, table, data):
    """
    cursor: psycopg2 cursor
    table: tablename
    data: a list of tuples containing data for the table
        CAUTION! data tuples must be in the correct order for the table
        ADVICE! You should correctly type your data before it reaches this point

    We mogrify in advance to get better speed
    This will store your ENTIRE query in memory in python. This is NOT efficient,
        so consider batching a higher level if you have a really giant query

    Check here: http://stackoverflow.com/questions/8134602/
                psycopg2-insert-multiple-rows-with-one-query
    """
    cursor = db.cursor()
    ncol = len(data[0])
    # looks ugly but creates (%s,%s,%s), with ncol %s
    placeholder = '(' + ','.join(['%s'] * ncol) + ')'
    # mogrify returns bytes, we need bytes
    preamble = b'INSERT INTO ' + bytes(table, 'utf8') + b' VALUES '
    # format the data tuples
    fmt_list = []
    for tup in data:
        try:
            fmt_list.append(cursor.mogrify(placeholder, tup))
        except:
            'Mogrify error!'
    fmt_data = b','.join(fmt_list)
    # create a big query string
    query = preamble + fmt_data
    cursor.execute(query)
    db.commit()

if __name__ == '__main__':
    db = psql_connect()
    print('Connected.')
    psql_setup(db)
    print('Setup successfully.')

    """
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



    # Insert edges #

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
                psql_insert_many(db, 'Edges', edge_data)
                edge_data = []
        psql_insert_many(db, 'Edges', edge_data)

    del edge_data
    """

    # Insert tweets #
    print('Starting insert.')

    tweet_count = 0

    file_list = glob.glob(SUCCESS_USER_PATTERN)
    with io.open(OUTFILE_NAME, 'w') as outfile:
        for fname in file_list:
            with bz2.open(fname, 'rt') as f:
                for line in f:
                    uid, data_json = line.split('\t', 1)
                    uid = uid.strip('"')
                    data = json.loads(data_json)
                    for tweet in data['tweets']:
                        tweet_tags = set()
                        tid = tweet['id_str']
                        text = re.sub(r'\s+', ' ', tweet['text'])
                        text = re.sub(r'\\', r"\\\\", text) + ' '
                        created_at = create_timestamp(tweet['created_at'])
                        # Skip tweets without a creation time
                        if len(created_at) < 10:
                            continue
                        for tag in tweet['entities']['hashtags']:
                            tweet_tags.add(tag['text'])
                        if len(tweet_tags) == 0:
                            tup = (uid, tid, text, created_at, "")
                            outfile.write('\t'.join(tup) + '\n')
                        else:
                            for tag in tweet_tags:
                                tup = (uid, tid, text, created_at, tag)
                                outfile.write('\t'.join(tup) + '\n')
            print('Done with file {}!'.format(fname))
