import collections as coll
import ujson as json
import glob
import bz2
import re
import sys
from helpers import psql_connect
from helpers import TW_DATE_FMT, PS_DATE_FMT, create_timestamp

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

if __name__ == '__main__':
    db = psql_connect()
    print('Connected.')
    psql_setup(db)
    print('Setup successfully.')

    # Insert tweets #
    print('Starting insert.')

    cursor = db.cursor()
    placeholder = '(' + ','.join(['%s'] * 5) + ')'
    preamble = b'INSERT INTO ' + bytes('SuccessTweets', 'utf8') + b' VALUES '

    tweet_data = []
    count = 0
    file_list = glob.glob(SUCCESS_USER_PATTERN)

    start_idx, stop_idx = int(sys.argv[1]), int(sys.argv[2])

    effective_flist = file_list[start_idx:stop_idx]
    print(len(effective_flist))

    # 301 - 1424, 0-indexed
    # 301 - 863, 863 - 1424

    for fname in effective_flist:
        with bz2.open(fname, 'r') as f:
            for line in f:
                uid, data_json = line.split(b'\t', 1)
                uid = int(uid.strip(b'"'))
                data = json.loads(data_json)
                for tweet in data['tweets']:
                    tweet_tags = set()
                    tid = tweet['id_str']
                    text = re.sub(r"\s+", r" ", tweet['text']) + ' '
                    created_at = create_timestamp(tweet['created_at'])
                    for tag in tweet['entities']['hashtags']:
                        tweet_tags.add(tag['text'])
                    if len(tweet_tags) == 0:
                        try:
                            tup = (uid, tid, text, created_at, None)
                            tweet_data.append(cursor.mogrify(placeholder, tup))
                        except:
                            print('Mogrify error!')
                        count += 1
                    else:
                        for tag in tweet_tags:
                            try:
                                tup = (uid, tid, text, created_at, tag)
                                tweet_data.append(
                                    cursor.mogrify(placeholder, tup)
                                )
                            except:
                                print('Mogrify error!')
                            count += 1
                    if count > 100000:
                        query = preamble + b','.join(tweet_data)
                        cursor.execute(query)
                        db.commit()
                        tweet_data = []
                        count = 0
                        print('Inserted another 100k!')
            print('Finished file {}!'.format(fname))
