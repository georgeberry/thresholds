library(AER)
library(sampleSelection)
library(stargazer)

#need to lay out tables with stargazer
#one table for each graph for broadcast, targeted
#targeted: need to represent: 1) true values; 2) tobit; 3) ols
#broadcast: need to represent: 1) true values; 2) unpruned sample tobit; 3) pruned sample tobit; 4) pruned with heckman

broadcast = c(
  '/Users/g/Google Drive/Fall 2014/diffusion/thresholds/data/broadcast_regular_output.csv',
  '/Users/g/Google Drive/Fall 2014/diffusion/thresholds/data/broadcast_poisson_output.csv',
  '/Users/g/Google Drive/Fall 2014/diffusion/thresholds/data/broadcast_watts_strogatz_output.csv',
  '/Users/g/Google Drive/Fall 2014/diffusion/thresholds/data/broadcast_power_law_output.csv'
  )
targeted = c(
  '/Users/g/Google Drive/Fall 2014/diffusion/thresholds/data/targeted_regular_output.csv',
  '/Users/g/Google Drive/Fall 2014/diffusion/thresholds/data/targeted_poisson_output.csv',
  '/Users/g/Google Drive/Fall 2014/diffusion/thresholds/data/targeted_watts_strogatz_output.csv',
  '/Users/g/Google Drive/Fall 2014/diffusion/thresholds/data/targeted_power_law_output.csv'
  )

#broadcast
for (file in broadcast){
  df = read.csv(file)
  df$activated.alters = df$activated.alters - .5
  obs = df[which(df$observed == 1),]
  
  true.vals = lm(true.threshold ~ var1 + var2+ bin_var1, data=df)
  unpruned.tobit = tobit(activated.alters ~ var1 + var2 + bin_var1, left = 0, right = Inf, dist="gaussian", data=df)
  df$activated.alters = df$activated.alters - .5
  pruned.tobit = tobit(activated.alters ~ var1 + var2 + bin_var1, left=0, right = Inf, dist="gaussian", data=obs)
  w = glm(observed~var1+var2+bin_var1, family=binomial(link=probit), data=df)
  f = fitted(w)
  df$fitted = f
  weighting = (1/f[which(df$observed == 1)])/sum(1/f[which(df$observed == 1)])
  obs$weighting = weighting
  pruned.weighted = tobit(activated.alters ~ var1 + var2 + bin_var1, left =0, right = Inf, dist="gaussian", data=obs, weights=obs$weighting)
  
  stargazer(true.vals, unpruned.tobit, pruned.tobit, pruned.weighted,
            covariate.labels=c('contstant', 'x1','x2','x3'),
            dep.var.labels=c('True Threshold', 'Observed S_i^*'),
            p=NA, df=F, intercept.top=T, intercept.bottom=F, se=NA, t=NA, keep.stat='n', report='vc'
            )
  }

for (file in targeted){
  df = read.csv(file)
  df$activated.alters = df$activated.alters - .5
  true.vals = lm(true.threshold ~ var1 + var2+ bin_var1, data=df)
  unpruned.tobit = tobit(activated.alters ~ var1 + var2 + bin_var1, left = 0, right = Inf, dist="gaussian", data=df)
  least.squares = lm(activated.alters ~ var1 + var2 + bin_var1, data=df)
  stargazer(true.vals, unpruned.tobit, least.squares,
            covariate.labels=c('constant', 'x1','x2','x3'),
            dep.var.labels=c('True Threshold', 'Observed S_i^*'),
            p=NA, df=F, intercept.top=T, intercept.bottom=F, se=NA, t=NA, keep.stat='n', report='vc'
  )
}