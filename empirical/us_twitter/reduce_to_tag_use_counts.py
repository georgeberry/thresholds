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