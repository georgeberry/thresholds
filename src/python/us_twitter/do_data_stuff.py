import collections as coll
import psycopg2
import json

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
    # EDGELIST_FILE =

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

def psql_insert_many(cursor, table, data):
    """
    cursor: psycopg2 cursor
    table: tablename
    data: a list of tuples containing data for the table
        CAUTION! data tuples must be in the correct order for the table

    Check here: http://stackoverflow.com/questions/8134602/
                psycopg2-insert-multiple-rows-with-one-query
    We mogrify in advance to get better speed
    This will store your ENTIRE query in memory in python. This is NOT efficient,
        so consider batching a higher level if you have a really giant query
    """
    ncol = len(data[0])
    # looks ugly but creates (%s,%s,%s), with ncol %s
    placeholder = '(' + ','.join(['%s'] * ncol) + ')'
    # format the data tuples
    fmt_data = b','.join(cursor.mogrify(placeholder, tup) for tup in data)
    # create a big query string
    query = 'INSERT INTO ' + table + ' VALUES ' + fmt_data
    print(query)
    cursor.execute(str(query))

if __name__ == '__main__':
    db = psql_connect()
    print('Connected.')
    psql_setup(db)
    print('Setup successfully.')

    # Name for server-side operations
    cursor = db.cursor(name="first")

    # List of tuples, (htag, count)
    ht_data = []

    with open(HTAG_COUNT_FILE, 'r') as f:
        for line in f:
            htag, count = line.strip('\n').split('\t')
            ht_data.append((str(htag), int(count)))

    print('Here\'s what the data looks like')
    print(ht_data[:10])

    psql_insert_many(cursor, 'Hashtags', ht_data)
    print('Inserted hashtags successfully!')
