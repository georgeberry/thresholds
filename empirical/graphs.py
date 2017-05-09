import itertools
import collections
from igraph import *

EDGELIST_PATH = '/Users/geb97/hashtag_edges.tsv'
NODE_DATA_PATH = '/Users/geb97/node_data_for_edges.tsv'

TEST_TAG = 'benghazi'

node_data = {}
vertices = set()
edges = set()

with open(EDGELIST_PATH, 'r') as infile:
    for line in infile:
        tag, src, src_time, dst, dst_time = line.split('\t')
        if tag == TEST_TAG:
            vertices.add(src)
            vertices.add(dst)
            edges.add((src, dst))
            if src not in node_data:
                node_data[src] = {}
            if dst not in node_data:
                node_data[dst] = {}
            node_data[src]['time'] = src_time
            node_data[dst]['time'] = dst_time
        else:
            break

with open(NODE_DATA_PATH, 'r') as infile:
    pass

#### graphs ####################################################################

g = Graph()
g.add_vertices(list(vertices))
g.add_edges(list(edges))

res = g.components()

subgraphs = res.subgraphs()

collections.Counter([x.vcount() for x in subgraphs])

g.transitivity_undirected()

g.transitivity_average_undirected()

g.transitivity_avglocal_undirected(
