# This file does RMSE analysis
# It generates two plots
#   1) RMSE vs error as fraction of r^2 (violin or boxplot)
#   2) RMSE as function of # training obs for various params
#
# The challenge here is how to deal with reps (computationally)
# Each param set will have its own folder
# We can read an entire folder, do the analysis, and then avg results
# For instance, for box in plot 1), we'll have 100 RMSE obs
# For plot 2), we'll have 100 obs for each X val for each param set
#   This is a lot, is there an easy way to draw the error bars?
