import itertools as itr
import collections as coll
import igraph as ig
#from igraph import *

EDGELIST_PATH = '/Users/Shared/hashtag_edges_sorted.tsv'
NODE_DATA_PATH = '/Users/Shared/node_data_for_edges.tsv'
FIRST_USE_PATH = '/Users/Shared/first_usages.tsv'
OUTFILE = '/Users/cjc73/Expire/net_stats.tsv'

TEST_TAG = 'benghazi'

NodeData = coll.namedtuple(
    'NodeData',
    ['exposure', 'in_interval', 'post_count']
)


def net_stats(vertices, edges, tag_name, outfile=None):
    print(f"Tag:{tag_name}")
    g = ig.Graph(directed=True)
    g.add_vertices(list(vertices))
    g.add_edges(list(edges))
    comp_sizes = coll.Counter(g.components(mode=ig.WEAK).sizes())
    total_size = g.vcount()
    max_size = max(comp_sizes) if total_size else 0
    top_2 = comp_sizes.most_common(2)
    one_v_2 = top_2[0][1]/sum(y for x, y in top_2) if len(top_2) == 2 else 1 
    if outfile:
        outfile.write(f"{tag_name}\t{max_size}\t{total_size}\t{one_v_2}\n")
    else:
        print(outfile.write(f"{tag_name}\t{max_size}\t{total_size}\t{one_v_2}"))


all_users_for_tag = dict()
with open(FIRST_USE_PATH, 'r') as infile:
    for line in infile:
        uid, tag, date = line.strip().split('\t')
        if not tag in all_users_for_tag:
            all_users_for_tag[tag] = {uid}
        else:
            all_users_for_tag[tag].add(uid)

# data for all nodes / all tags
all_node_data = {}
with open(FIRST_USE_PATH, 'r') as infile:
    for line in infile:
        uid, tag, date = line.strip().split('\t')
        if not uid in all_node_data:
            all_node_data[uid] = {tag:date}
        else:
            all_node_data[uid][tag] = date
            
with open(NODE_DATA_PATH, 'r') as infile:
    for line in infile:
        uid, tag, exposure, in_interval, post_count = line.strip().split('\t')
        line_data = NodeData(exposure, in_interval, post_count)
        if not uid in all_node_data:
            all_node_data[uid] = {tag:line_data}
        else:
            all_node_data[uid][tag] = line_data

# get data tag by tag
current_tag = None
with open(EDGELIST_PATH, 'r') as infile, open(OUTFILE, 'w') as outfile:
    outfile.write(f"tag\tgc_size\tg_size\tone_to_two\n")
    for line in infile:
        tag, src, src_time, dst, dst_time = line.strip().split('\t')
        if tag != current_tag:
            if current_tag:
                net_stats(vertices, edges, current_tag, outfile=outfile)
            node_data = {}
            vertices = all_users_for_tag.get(tag, set())
            edges = set()
            current_tag = tag
        else:
            vertices.add(src)
            vertices.add(dst)
            if src_time > dst_time:
                src, src_time, dst, dst_time = dst, dst_time, src, src_time
            edges.add((src, dst))
#             for uid in (src, dst):
#                 if uid not in node_data:
#                     node_data[uid] = {
#                         k:v for k, v in zip(
#                             all_node_data[uid][tag]._fields, 
#                             all_node_data[uid][tag]
#                         )
#                     }
            
#            node_data[src]['time'] = src_time
#            node_data[dst]['time'] = dst_time

    net_stats(vertices, edges, tag, outfile=outfile)


#### graphs ####################################################################

g = ig.Graph(directed=True)
g.add_vertices(list(vertices))
g.add_edges(list(edges))
res = g.components()
subgraphs = res.subgraphs()
collections.Counter([x.vcount() for x in subgraphs])






g = Graph()
g.add_vertices(list(vertices))
g.add_edges(list(edges))

res = g.components()

subgraphs = res.subgraphs()

collections.Counter([x.vcount() for x in subgraphs])

g.transitivity_undirected()

g.transitivity_average_undirected()

g.transitivity_avglocal_undirected(
