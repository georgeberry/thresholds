# To-dos
1. disentangle bias and variance from increased error sd
2. plot this nicely
3. Add empirical networks from Facebook (built in homophily!)
4. Add the medical diffusion network, to link up with old school soc people

## Bias vs Variance
As we increase the error sd, we reduced explained variance (and therefore increase unexplained variance), yet we also appear to increase the bias because the selection on the error is worse.

To fix this, we can do a couple of things:
1. Get error among the correctly measured thresholds
2. Plot how the prediction-RMSE changes relative to the ideal-RMSE as we increase error variance
3. Bootstrap the coefficients for model runs and see the mean/sd here

## Empirical networks

### Thresholds based on covariates

The thing our simulations don't do well is threshold homophily. It's pretty difficult to build this into a model.

Rather, we can use the empirical homophily in a real network to create a threshold distribution that is homophilous. We can then run our procedure with these homophilous thresholds.

### How well does our method work in small networks

We can take Coleman's diffusion of innovations data and apply our method to this from the outside. How many thresholds do we correctly measure? Is there a way to quantify how not-wrong we are?
