# This file reads in data from our simulations
# Simulation data has one row per node
# There is a before activation and after activation observation on each line
#
# With this data, we want to do the following:
#   1. Plot threshold distributions for obseved and missing nodes
#   2. Plot threshold distributions using the p(k) curve method
#   3.

library(ggplot2)
library(sampleSelection)
