import ujson as json
import psycopg2
import datetime as dt

TW_DATE_FMT = "%a %b %d %H:%M:%S %z %Y"
PS_DATE_FMT = "%Y-%m-%d %H:%M:%S%z"

def create_timestamp(twitter_datestring):
    """
    Twitter gives format Mon Jul 28 14:29:09 +0000 2014
    We need format 2014-07-28 14:29:09+00, where +00 is timezone
    """
    date = dt.datetime.strptime(twitter_datestring, TW_DATE_FMT)
    # chop off last 2 characters of timezone for postgres
    return date.strftime(PS_DATE_FMT)[:-2]

# Read from config.json, not pushed to git for privacy
# These config options should be treated as constants
with open('config.json', 'r') as f:
    j = json.load(f)
    PSQL_USR, PSQL_PWD = j['psql_usr'], j['psql_pwd']
    HTAG_COUNT_FILE = j['htag_counts']
    # TIMELINE_FOLDER =
    EDGELIST_FILE = j['edgelist']
    SUCCESS_USER_PATTERN = j['success_pattern']
    OUTPUT_FILE = j['output_file']

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
