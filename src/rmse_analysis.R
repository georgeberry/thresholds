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

# we want to get all the filenames, and strip


DATA_PATH = ""
all_files = list.files(DATA_PATH)

SimplifyFiles = function(){

}

file_batches = SimplifyFiles(all_files)

# want to do analysis for all files in a "batch"
# a "batch" is all runs with same params
# we need to do a set of anlayses to each batch separately
# what do we want from each batch?
#   1) RMSE and a summary of parameters
#   2) RMSE @ # of training obs

# important params that are going to make 2) hard to display:
#   a) size of graph

# gives imporant params + RMSE for one run
RmseSummary = function(){

}

# gives RMSE at number obs (maybe every 10?)
RmseAtNumTrainingObs = function(){

}
