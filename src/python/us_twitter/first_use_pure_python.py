from find_users_for_tags import TW_DATE_FMT, PS_DATE_FMT, create_timestamp

FNAME = '/Volumes/Starbuck/class/twitter_data/jq_filtered/part-00000.bz2.tsv'
OUTFILE = 'test.tsv'

# (uid, htag): (first_use, tid)
first_use_dict = {}

with open(FNAME, 'r') as f:
    for line in f:
        hashtag, uid, tid, created_at = line.split('\t')
        created_at = dt.datetime.strptime(created_at, TW_DATE_FMT)
        key = (uid, htag)
        val = (created_at, tid)
        if key not in first_use_dict:
            first_use_dict[key] = val
        else:
            prev_created_at, tid = first_use_dict[key]
            if created_at < prev_created_at:
                first_use_dict[key] = val

# column ordering: uid, tid, created_at, hashtag
with open(OUTFILE, 'w') as g:
    for key, val in first_use_dict.items():
        uid, hashtag = key
        created_at, tid = val
        g.write('\t'.join(uid, tid, created_at, hashtag) + '\n')
