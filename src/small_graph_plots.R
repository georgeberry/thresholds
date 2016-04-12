# This file creates our small-graph plots to illustration collisions

library(network)

dyad_edgelist = matrix(c(1, 2), byrow=TRUE, nrow=1)
triad_edgelist = matrix(c(1,2, 2,3, 3,1), byrow=TRUE, nrow=3)
tetrad_edgelist = matrix(c(1,2, 2,3, 3,1, 1,4, 3,4), byrow=TRUE, nrow=5)

dyad = network(dyad_edgelist, matrix.type='edgelist', directed=FALSE)
dyad %n% 'net.name' = 'Dyad'




triad = network(triad_edgelist, matrix.type='edgelist', directed=FALSE)
tetrad = network(tetrad_edgelist, matrix.type='edgelist', directed=FALSE)
# tetrad is not complete
