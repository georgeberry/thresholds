# Objective

We'd like to obtain info on full cascades for certain hashtags. Given a set of hashtags `H`, we extract the following items:

1. All users `U` of each tag in `H`
1. Timelines for each `U`
1. A record of first usages of relevant hashtags
1. Edges where both users are in `U`

The data we need to extract from raw is simple: the timelines for users in `U`

The algorithm is simple, take `H` as an input and then, if at least one tweet uses the tag, save the timeline

The output format is, at most 1 tag per line
`uid, tid, text, created_at, hashtag`

We can do the additional processing when we insert into postgres

# Data

## Raw data

Raw crawl and edgelist data

Crawl data: `/Volumes/Starbuck/class/twitter_data/modified_essential/US_GB_CA_AU_NZ_SG/`

Contains 1425 `.bz2`-zipped files. Each file has the format of:

`"uid" <tab> "{'user': user_info, 'tweets': [{tweet_dict}, ...]}"`

There are about 30m tweets per file, of which 10% or so have hashtag usages

## Intermediate data

Decompressed & extracted from raw data

## Analysis data

Postgres db, see `schema.sql`

1. `htag_counts`:
1. `edges`:
1. `tweets`:
1.

"htag_counts": "/Volumes/Starbuck/class/twitter_data/utags_by_user/user_counts.tsv",
"edgelist": "/Volumes/pci_ssd/twitter_patrick/bidirected_us_edges/success_plus_edgelist.ncol",
"success_pattern": "/Volumes/Starbuck/class/twitter_data/filtered_timelines/success_part-*.bz2",
"output_file": "success_tweets.tsv",
"nbr_tag_pattern": "/Volumes/Starbuck/class/twitter_data/jq_filtered/part-*.bz2.tsv"
