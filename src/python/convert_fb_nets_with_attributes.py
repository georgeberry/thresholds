# -*- coding: utf-8 -*-
"""
Created on Thu Mar 26 15:09:09 2015

@author: cjc73


%cd /Users/Shared/Vesta/facebook100

import scipy.io as sio
import igraph as ig


sio.whosmat('/Users/Shared/Vesta/facebook100/Reed98.mat')
mat_contents = sio.loadmat('/Users/Shared/Vesta/facebook100/Reed98.mat')

mat_contents = sio.loadmat('/Users/Shared/Vesta/facebook100/Caltech36.mat')


G_mat = ig.Graph(edges=zip(*mat_contents['A'].nonzero()), directed=False)

"""

#%%
#import sys,
import os, os.path
import scipy.io as sio
#import numpy as np
import igraph as ig

taskDir = '/Volumes/Neptune/semi_public_datasets/facebook100'
outDir = '/Volumes/Neptune/semi_public_datasets/facebook100/graphml_gc'

files = ( os.listdir(taskDir) )
tasks = (f for f in files if os.path.splitext(f)[1] in ['.mat'])  
completed_tasks = set( f.split('_')[0]+'.mat' for f in os.listdir(outDir) )


# 0 student/faculty status flag
# 1 gender,
# 2 major,
# 3 second major/minor (if applicable),
# 4 dorm/house,
# 5 year
# 6 high school. 
# Missing data is coded 0

names = [ 
'student', 'gender', 'major', 'major2',
'dorm', 'year', 'high_school',
]

name_idx_pairs = [ (name,idx) for idx, name in enumerate(names) ]


for infile in tasks: 
    
    if infile in completed_tasks:
        continue
    
    try:    
        mat_contents = sio.loadmat(os.path.join(taskDir,infile))
        
        G_mat = ig.Graph(edges=zip(*mat_contents['A'].nonzero()), directed=False) 
        G_mat.vs['name'] = range(len(G_mat.vs))
        
        for name, idx in name_idx_pairs:
            G_mat.vs[name] = mat_contents['local_info'][:,idx]
        
        G_mat_g =G_mat.components().giant().simplify()
        
        # print(infile, G_mat.vcount(), G_mat_g.vcount())
        outfile_name = os.path.join(outDir,os.path.splitext(infile)[0]+'_gc.graphml' )
        with open(outfile_name, 'w') as outfile:    
            G_mat_g.write_graphml( outfile )
            
    except KeyError:
        print("Error reading file '{}'".format(infile))
        



#%%
