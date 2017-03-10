#!/usr/local/bin/python3

import bz2
import io
import json
import click
import os
import datetime as dt

TW_DATE_FMT = "%a %b %d %H:%M:%S %z %Y"
PS_DATE_FMT = "%Y-%m-%d %H:%M:%S%z"

def load_watch_tags():
    infile_name = '/Volumes/Starbuck/class/twitter_data/utags_by_user/tags_watched.tsv'
    with open(infile_name) as infile:
        tag_set = set(json.load(infile))
    return tag_set

def load_users():
    json_out = '/Volumes/pci_ssd/twitter_patrick/bidirected_us_edges/success_plus_users.json'
    with open(json_out) as outfile:
        user_set = set(json.load(outfile))
    return user_set

def get_tweets_for_hashtags_from_bz2_file(infile_name, outfile_name, tag_set, user_set):
    header_vals = ['uid', 'tid', 'raw_text', 'created_at', 'hashtag']
    with bz2.open(infile_name) as infile, io.open(outfile_name, 'w') as outfile:
        #header_str = '\t'.join(header_vals)+'\n'
        #outfile.write(header_str)
        for i, line in enumerate(infile):
            #if i > 10: break
            uid, data_json = line.split(b'\t', 1)
            if not uid[1:-1].decode('utf8') in user_set:
                continue
            data = json.loads(data_json)
            try:
                for tweet in data['tweets']:
                    for tag in tweet['entities']['hashtags']:
                        if tag['text'] in tag_set:
                            out = {
                                'uid':data['user'][0]['id_str'],
                                'tid':tweet['id_str'],
                                'hashtag':tag['text'],
                                'raw_text':tweet['text'].replace('\t', ' '),
                                'created_at':create_timestamp(tweet['created_at']),
                            }
                            write_entry(out, header_vals, outfile)
            except KeyError as e:
                print(e)

def write_entry(out, header_vals, outfile):
    out_str = '\t'.join(out[x] for x in header_vals) + '\n'
    outfile.write(out_str)

def create_timestamp(twitter_datestring):
    """
    Twitter gives format Mon Jul 28 14:29:09 +0000 2014
    We need format 2014-07-28 14:29:09+00, where +00 is timezone
    """
    date = dt.datetime.strptime(twitter_datestring, TW_DATE_FMT)
    # chop off last 2 characters of timezone for postgres
    return date.strftime(PS_DATE_FMT)[:-2]

@click.command()
@click.argument('in_file_path', type=click.Path(exists=True))
def main(in_file_path):
    #print('run')
    out_file_path = '/Volumes/Starbuck/class/twitter_data/tweets_by_tag/'
    in_name = os.path.splitext(os.path.basename(in_file_path))[0]
    outfile_name = os.path.join(out_file_path, in_name+'.tsv')
    #print(in_file_path)
    print(outfile_name)
    tag_set = load_watch_tags()
    user_set = load_users()
    get_tweets_for_hashtags_from_bz2_file(in_file_path, outfile_name, tag_set, user_set)

if __name__ == '__main__':
    main()

# find /Volumes/Starbuck/class/twitter_data/modified_essential/US_GB_CA_AU_NZ_SG/part-*.bz2 -print0 | xargs -0 -n1 -P6 -- bash -c '~/find_users_for_tags.py "$0"'
