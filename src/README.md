# To-dos

1. disentangle bias and variance from increased error sd (DONE)
2. plot this nicely
3. Add empirical networks from Facebook (built in homophily!)
4. Add the medical diffusion network, to link up with old school soc people (DONE; USELESS)
5. Double check `rmse_analysis.R` to make sure it's modeling correctly

## Plots

1. Complete graph analysis, everyone has threshold 1, demonstrate upward bias

## Bias vs Variance
As we increase the error sd, we reduced explained variance (and therefore increase unexplained variance), yet we also appear to increase the bias because the selection on the error is worse.

To fix this, we can do a couple of things:

1. Get error term among the correctly measured thresholds (DONE)
2. Get rmse vs true rmse (DONE)
3. Get coefficients (DONE)
4. Plot error terms as function of params (DONE)
5. Plot rmse vs true as fn of params (DONE)
6. Plot coefficient error as fn of params (DONE)
7. Make pretty plots of collisions for all graph simulation types
8. Use the threshold condition on simple empirical data (e.g. Coleman)

## Empirical networks

### Coleman dataset

1. Follow Burt and do the professional advice network (exclude friendship ties)
2. Repeat Valente's analysis of early-late-middle threshold by overall comparison
3. Give analysis of the difference between

### Thresholds based on covariates

The thing our simulations don't do well is threshold homophily. It's pretty difficult to build this into a model.

Rather, we can use the empirical homophily in a real network to create a threshold distribution that is homophilous. We can then run our procedure with these homophilous thresholds.

### How well does our method work in small networks

We can take Coleman's diffusion of innovations data and apply our method to this from the outside. How many thresholds do we correctly measure? Is there a way to quantify how not-wrong we are?

### Natural experiment?

Can we view the network diffusion process as inducing many natural experiments? Many tiny natural experiments lolol.
