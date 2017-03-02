#!/usr/local/bin/python3

import bz2
import io
import json
import click
import os

def load_watch_tags(watchfile, cutoff=1000):
    infile_name = '/Volumes/Starbuck/class/twitter_data/utags_by_user/user_counts_lc.tsv'
    tag_set = set()
    with io.open(infile_name) as infile:
        for line in infile:
            tag, count = line.strip().split('/t')
            if count < cutoff:
                break
            tag_set.add(tag)

def get_uid_hashtags_from_bz2_file(infile_name, outfile_name, tag_set):
    with bz2.open(infile_name) as infile, io.open(outfile_name, 'w') as outfile:
        for i, line in enumerate(infile):
            #if i > 10: break
            user_tags = set()
            uid, data_json = line.split(b'\t', 1)
            data = json.loads(data_json)
            try:
                for tweet in data['tweets']:
                    for tag in tweet['entities']['hashtags']:
                        user_tags.add(tag['text'])
            except KeyError as e:
                print(e)
            uid = data['user'][0]['id_str']
            j_str = json.dumps({uid:list(user_tags)})
            #print(j_str)
            outfile.write(j_str+'\n')

@click.command()
@click.argument('in_file_path', type=click.Path(exists=True))
def main(in_file_path):
    #print('run')
    out_file_path = '/Volumes/Starbuck/class/twitter_data/utags_by_user/'
    in_name = os.path.splitext(os.path.basename(in_file_path))[0]
    outfile_name = os.path.join(out_file_path, in_name+'.json')
    #print(in_file_path)
    print(outfile_name)
    get_uid_hashtags_from_bz2_file(in_file_path, outfile_name)


if __name__ == '__main__':
    main()



# find /Volumes/Starbuck/class/twitter_data/filtered_timelines/success_part-*.bz2 -print0 | xargs -0 -n1 -P12 -- bash -c '~/extract_tags_from_tweets.py "$0"'
