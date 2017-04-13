"""
All dyads, triads, and tetrads with all graph structures
and all thresholds of 0, 1, 2, 3

Questions:
- Constraints on dyadic threshold differenes?
- Update times?
"""

import networkx as nx
from networkx.generators.atlas import *


a = graph_atlas_g()


print(a[0])

print('hi \n hi \n hi')

import networkx as nx

import matplotlib.pyplot as plt

G=nx.cycle_graph(4)

H=nx.path_graph(4)

plt.figure(1)

nx.draw(G)

plt.figure(2)

nx.draw(H)

plt.show()




G1 = nx.balanced_tree(2,1)
G2 = nx.balanced_tree(2,2)


elarge1 =[(u,v) for (u,v,d) in G1.edges(data=True)]
elarge2 =[(u,v) for (u,v,d) in G2.edges(data=True)]


pos1=nx.spring_layout(G1)
pos2=nx.spring_layout(G2)


for k,v in pos2.items():
    # Shift the x values of every node by 10 to the right
    v[0] = v[0] + 10

nx.draw_networkx_nodes(G1,pos1,node_size=50,node_color='b')
nx.draw_networkx_edges(G1,pos1,edgelist=elarge1,width=1,style='solid')


nx.draw_networkx_nodes(G2,pos2,node_size=10)
nx.draw_networkx_edges(G2,pos2,edgelist=elarge2,width=1)

plt.show() # display
plt.draw()
