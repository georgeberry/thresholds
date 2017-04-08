# This file creates our small-graph plots to illustration collisions
# Because of how ggnet2 scales node positions, we create two missing (not plotted) nodes at 0,0 and 1,1
# This creates the scale against which to plot the rest of our nodes
# These nodes have index 1-2

library(network)
library(RColorBrewer)

vertex_size = 8

## dyad ## 

dyad_edgelist = matrix(c(1,2), byrow=TRUE, nrow=1)
dyad = network(dyad_edgelist, matrix.type='edgelist', directed=FALSE)
dyad_coords = matrix(c(0.0, -0.9, 0.0, 0.9), byrow=TRUE, nrow=2)
dyad %v% "vertex.names" = c("0","0")

png(file = "/Users/g/Google Drive/project-thresholds/writeup/dyadplot.png", width=1200, height=800, res=200)
par(mfrow=c(1,2), mar=c(5,0,1,0), oma=c(0,0,0,0), cex.lab=2)
#plot(dyad, coord = dyad_coords, vertex.col=c("cadetblue3", "cadetblue3"), jitter=FALSE, vertex.cex=vertex_size, label=dyad %v% "vertex.names", label.pos=5, label.cex=2)
plot(dyad, coord = dyad_coords, vertex.col=c("cadetblue3", "goldenrod1"), jitter=FALSE, vertex.cex=vertex_size, label=dyad %v% "vertex.names", label.pos=5, label.cex=2, vertex.sides=c(50, 4), vertex.rot=c(0,45), xlab="t = 1")
plot(dyad, coord = dyad_coords, vertex.col=c("goldenrod1","goldenrod1"), jitter=FALSE, vertex.cex=vertex_size, label=dyad %v% "vertex.names", label.pos=5, label.cex=2, vertex.sides=c(3, 4), vertex.rot=c(30,45), xlab="t = 2")
dev.off()

## triad ##

triad_edgelist = matrix(c(1,2, 2,3, 3,1), byrow=TRUE, nrow=3)
triad = network(triad_edgelist, matrix.type='edgelist', directed=FALSE)
triad %v% 'vertex.names' = c("0", "1", "1")
triad_coords = matrix(c(0.0, 0.8, -0.8, -0.8, 0.8, -0.8), byrow=TRUE, nrow=3)
triad_vsize = 9
triad_vlabel = 2.5

png(file = "/Users/g/Google Drive/project-thresholds/writeup/triadplot.png", width=1600, height=800, res=200)
par(mfrow=c(1,3), mar=c(5,1,1,1), oma=c(0,0,0,0), cex.lab=3)
#par(mfrow=c(1, 3), mar=c(15,1,15,1), mgp=c(0,0,0), cex.lab=4)
#plot(triad, coord=triad_coords, jitter=FALSE, vertex.col=c("cadetblue3", "cadetblue3", "cadetblue3"), vertex.cex=vertex_size, label=triad %v% "vertex.names", label.pos=5, label.cex=2)
plot(triad, coord=triad_coords, jitter=FALSE, vertex.col=c("goldenrod1", "cadetblue3", "cadetblue3"), vertex.cex=triad_vsize, label=triad %v% "vertex.names", label.pos=5, label.cex=triad_vlabel, vertex.sides=c(4, 50, 50), vertex.rot=c(45,0,0), xlim=c(-1,1), ylim=c(-1,1), xlab="t = 1")
plot(triad, coord=triad_coords, jitter=FALSE, vertex.col=c("goldenrod1", "goldenrod1", "cadetblue3"), vertex.cex=triad_vsize, label=triad %v% "vertex.names", label.pos=5, label.cex=triad_vlabel, vertex.sides=c(4, 4, 50), vertex.rot=c(45,45,0), xlim=c(-1,1), ylim=c(-1,1), xlab="t = 2", pad=0)
plot(triad, coord=triad_coords, jitter=FALSE, vertex.col=c("goldenrod1", "goldenrod1", "goldenrod1"), vertex.cex=triad_vsize, label=triad %v% "vertex.names", label.pos=5, label.cex=triad_vlabel, vertex.sides=c(4, 4, 3), vertex.rot=c(45,45,30), xlim=c(-1,1), ylim=c(-1,1), xlab="t = 3", pad=0)
dev.off()


## tetrad ##

tetrad_edgelist = matrix(c(1,2, 2,3, 3,1, 2,4, 3,4), byrow=TRUE, nrow=5)
tetrad = network(tetrad_edgelist, matrix.type='edgelist', directed=FALSE)
tetrad %v% "vertex.names" = c("0", "1", "1", "1")
tetrad_coords = matrix(c(-1.1,0, 0,.7, 0,-.7, 1.1,0), byrow=TRUE, nrow=4)

png(file = "/Users/g/Google Drive/project-thresholds/writeup/tetradplot.png", width=1600, height=800, res=200)
par(mfrow=c(1,3), mar=c(5,1,1,1), oma=c(0,0,0,0), cex.lab=3)
#plot(tetrad, coord=tetrad_coords, jitter=FALSE, vertex.col=c("cadetblue3","cadetblue3","cadetblue3","cadetblue3"), vertex.cex=vertex_size, label=tetrad %v% "vertex.names", label.pos=5, label.cex=2)
plot(tetrad, coord=tetrad_coords, jitter=FALSE, vertex.col=c("goldenrod1","cadetblue3","cadetblue3","cadetblue3"), vertex.cex=vertex_size, label=tetrad %v% "vertex.names", label.pos=5, label.cex=2, vertex.sides=c(4,50,50,50), vertex.rot=c(45,0,0,0), xlab="t=1")
plot(tetrad, coord=tetrad_coords, jitter=FALSE, vertex.col=c("goldenrod1","goldenrod1","goldenrod1","cadetblue3"), vertex.cex=vertex_size, label=tetrad %v% "vertex.names", label.pos=5, label.cex=2, vertex.sides=c(4,4,4,50), vertex.rot=c(45,45,45,0), xlab="t=2")
plot(tetrad, coord=tetrad_coords, jitter=FALSE, vertex.col=c("goldenrod1","goldenrod1","goldenrod1","goldenrod1"), vertex.cex=vertex_size, label=tetrad %v% "vertex.names", label.pos=5, label.cex=2, vertex.sides=c(4,4,4,3), vertex.rot=c(45,45,45,180), xlab="t=3")
dev.off()

