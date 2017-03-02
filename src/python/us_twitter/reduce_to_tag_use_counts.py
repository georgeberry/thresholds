
###############################################################################
# Extract tags for the users with geotags

import os
import json
import collections as coll
import glob

res = coll.Counter()
for infile_name in glob.glob("success_part-*.json"):
    print(infile_name)
    with open(infile_name) as infile:
        for line in infile:
            for kset in json.loads(line).values():
                res.update(kset)

with open("user_counts.tsv", "w") as outfile:
    for tag, count in res.most_common():
        if count < 10:
            break
        outfile.write("{}\t{}\n".format(tag, count))
        
        
        
res = coll.Counter()
for infile_name in glob.glob("success_part-*.json"):
    print(infile_name)
    with open(infile_name) as infile:
        for line in infile:
            for kset in json.loads(line).values():
                res.update(set(x.lower() for x in kset))

with open("user_counts_lc.tsv", "w") as outfile:
    for tag, count in res.most_common():
        if count < 10:
            break
        outfile.write("{}\t{}\n".format(tag, count))
        

# Get the users of each tag:   
in_file_pat = "/Volumes/Starbuck/class/twitter_data/modified_essential/US_GB_CA_AU_NZ_SG/part-*.bz2"    
tag_users = dict()
for infile_name in glob.glob("success_part-*.json"):
    print(infile_name)
    with open(infile_name) as infile:
        for line in infile:
            for uid, tags in json.loads(line).items():
                for tag in (x.lower() for x in tags):
                    if res[tag] < 1000:
                        continue
                    user_list = tag_users.get(tag, list())
                    user_list.append(uid)
                    tag_users[tag] = user_list

for tag, users in tag_users.items():
    if len(users) < 1000:
        continue
    with open(os.path.join('tag_users', tag+'.json'), 'w') as outfile:
        json.dump({tag:users}, outfile)
        
###############################################################################
# Load the US bi-directed graph (this has been converted to ncol format)
# subset the graph on users with geopoints

import igraph as ig
import collections as coll
import json

# get list of success users
price_file_name = '/Volumes/Starbuck/class/house_prices/house_price_success.json'
uid_set = set()
with open(price_file_name) as home_prices:
    for i, user in enumerate(home_prices):
        try:
            record = json.loads(user)
            uid = record['uid']
            uid_set.add(uid)
        except ValueError as e:
            print("End of File: {} cases read".format(i)) 
            break

ncol_file = '/Volumes/pci_ssd/twitter_patrick/bidirected_us_edges/US_bidirected_edgelist.ncol'
ncol_out = '/Volumes/pci_ssd/twitter_patrick/bidirected_us_edges/success_plus_edgelist.ncol'

with open(ncol_file) as infile, open(ncol_out, 'w') as outfile:
    for line in infile:
        src, dest = line.strip().split()
        if src in uid_set or dest in uid_set:
            outfile.write(line)        

# < 10 mins
# hb_graph = ig.Graph.Read_Ncol(ncol_out, weights=None, directed=False)

# get the node set from edges
uid_plus_set = set()
with open(ncol_out) as infile:
    for line in infile:
        src, dest = line.strip().split()
        uid_plus_set.add(src)
        uid_plus_set.add(dest)
        
# get tags that are used by <= 50,000 people
tag_set = set()
tag_file = '/Volumes/Starbuck/class/twitter_data/utags_by_user/user_counts.tsv'
with open(tag_file) as infile:
    for line in infile:
        tag, count_str = line.strip().split('\t')
        count = int(count_str)
        if count <= 50000:
            tag_set.add(tag)
        if len(tag_set) > 10000:
            break

tag_out_file = '/Volumes/Starbuck/class/twitter_data/utags_by_user/tags_watched.tsv'
with open(tag_out_file) as outfile:
    json.dump(list[tag_set], outfile)
               



