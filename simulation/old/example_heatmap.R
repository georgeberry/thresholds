library(ggplot2)
library(reshape2)
library(plyr)
library(scales)

nba = read.csv("http://datasets.flowingdata.com/ppg2008.csv")

nba$Name = with(nba, reorder(Name, PTS))

nba.m = melt(nba)

nba.m <- ddply(nba.m, .(variable), transform, rescale = rescale(value))
nba.pts = nba.m[nba.m$variable == "PTS",]

nba.two = nba.m[nba.m$variable %in% c("PTS", "AST"),]

ggplot(nba.two, aes(Name, variable)) + geom_tile(aes(fill = rescale), colour="white") + scale_fill_gradient(low="white", high="steelblue")
