# To-dos

1. Plot bias v variance nicely
2. Add empirical networks from Facebook (built in homophily!)
3. Double check `rmse_analysis.R` to make sure it's modeling correctly (DONE)

## Bias vs Variance
As we increase the error sd, we reduced explained variance (and therefore increase unexplained variance), yet we also appear to increase the bias because the selection on the error is worse.

To fix this, we can do a couple of things:

1. Get error term among the correctly measured thresholds (DONE)
2. Get rmse vs true rmse (DONE)
3. Get coefficients (DONE)
4. Plot error terms as function of params (DONE)
5. Plot rmse vs true as fn of params (DONE)
6. Plot coefficient error as fn of params (DONE)
7. Make pretty plots of collisions for all graph simulation types (DONE)
8. Use the threshold condition on simple empirical data (e.g. Coleman) (DONE)
9. Debug the prediction-at-k code (wrong baselines)
10. Debug the NA's in the empirical sims
11. Make graphs higher res and re-place legends
12. In the writeup, fix the formalization: specifically base it on the minimum `d_i`



## Empirical networks

### Fb topologies

Pick FB topologies from the Facebook 100 dataset.
Need to find functions that are appropriate

I just picked two for early analysis. The function might have to be tuned for the graph specifically (i.e. the constant is 5 times the mean degree, or something like that)



### Coleman dataset

1. Follow Burt and do the professional advice network (exclude friendship ties) (DONE)
2. Repeat Valente's analysis of early-late-middle threshold by overall comparison (DONE)
3. Give analysis of the difference between (DONE)

### Thresholds based on covariates

The thing our simulations don't do well is threshold homophily. It's pretty difficult to build this into a model.

Rather, we can use the empirical homophily in a real network to create a threshold distribution that is homophilous. We can then run our procedure with these homophilous thresholds.

### How well does our method work in small networks

We can take Coleman's diffusion of innovations data and apply our method to this from the outside. How many thresholds do we correctly measure? Is there a way to quantify how not-wrong we are?

### Natural experiment analogue?

Can we view the network diffusion process as inducing many natural experiments? Many tiny natural experiments lolol.

###
