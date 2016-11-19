RMSE_PATH = '/Users/g/Drive/projects-current/project-thresholds/data/sim_rmse_df.csv'

df_rmse = read.csv(RMSE_PATH)

df_reg = df_rmse %>%
  filter(graph_type=='plc', epsilon_dist_sd==1) %>%
  group_by(mean_deg) %>%
  summarize(beta_true = mean(beta_true),
            cons_true = mean(cons_true),
            beta_mean_meas = mean(beta_measured_ols),
            beta_lcl_meas = quantile(beta_measured_ols, 0.025),
            beta_ucl_meas = quantile(beta_measured_ols, 0.975),
            cons_mean_meas = mean(cons_measured_ols),
            cons_lcl_meas = quantile(cons_measured_ols, 0.025),
            cons_ucl_meas = quantile(cons_measured_ols, 0.975),
            beta_mean_activated = mean(beta_activated_ols),
            beta_lcl_activated = quantile(beta_activated_ols, 0.025),
            beta_ucl_activated = quantile(beta_activated_ols, 0.975),
            cons_mean_activated = mean(cons_activated_ols),
            cons_lcl_activated = quantile(cons_activated_ols, 0.025),
            cons_ucl_activated = quantile(cons_activated_ols, 0.975))