library(ggplot2)
library(reshape)
library(dplyr)

RMSE_PATH = '/Users/g/Drive/projects-current/project-thresholds/data/sim_rmse_df.csv'
K_PATH = '/Users/g/Drive/projects-current/project-thresholds/data/sim_k_df.csv'

#### RMSE processing ##########################################################
# The following variables are important
# - rmse_measured_ols
# - rmse_true
# - rmse_activated_ols
# - rmse_activated_naive

df_rmse = read.csv(RMSE_PATH)

m = melt(df_rmse,
         measure.vars=c('rmse_measured_ols',
                        'rmse_true',
                        'rmse_activated_ols',
                        'rmse_activated_naive'),
         id.vars=c('graph_type', 'mean_deg', 'epsilon_dist_sd'))

rmse_plot_df = m %>%
  group_by(graph_type, mean_deg, epsilon_dist_sd, variable) %>%
  summarize(
    mean=mean(value),
    se=sd(value),
    ucl=mean+1.96*se,
    lcl=mean-1.96*se
  )

rmse_plot_df$variable = ordered(factor(rmse_plot_df$variable),
                                levels=c('rmse_true',
                                         'rmse_measured_ols',
                                         'rmse_activated_ols',
                                         'rmse_activated_naive'))

make_rmse_plot = function(rmse_plot_df, graph, epsilon_sd, title) {
  p = rmse_plot_df %>%
    filter(graph_type==graph,
           epsilon_dist_sd==epsilon_sd) %>%
    ggplot(.) +
    geom_errorbar(aes(y=mean,
                      ymax=ucl,
                      ymin=lcl,
                      x=factor(mean_deg),
                      color=factor(variable),
                      width=0.4),
                  position='dodge') +
    theme_bw() +
    labs(title=title, y='RMSE') + 
    theme(axis.title.x=element_blank())
  return(p)
}

make_rmse_plot(rmse_plot_df, 'plc', 1, 'Power-law RMSE')
make_rmse_plot(rmse_plot_df, 'ws', 1, 'Watts-Strogatz RMSE')

#### another take on RMSE plots ################################################

mm = m
mm$variable = ordered(factor(mm$variable),
                      levels=c('rmse_true',
                               'rmse_measured_ols',
                               'rmse_activated_ols',
                               'rmse_activated_naive'))

mm %>%
  filter(epsilon_dist_sd==1.0, graph_type=='plc') %>%
  ggplot(.) +
    geom_point(aes(y=value, x=factor(mean_deg), color=variable),
               position=position_dodge(width=0.4)) +
    geom_hline(yintercept=1, linetype='dashed') +
    scale_y_continuous(breaks=c(0,2,4,6,8,10), limits=c(0,11)) +
    theme_bw()

#### k-df processing ###########################################################

df_k = read.csv(K_PATH)

k_plot_df = df_k %>%
  group_by(epsilon_dist_sd, graph_type, mean_deg, k) %>%
  summarize(
    rmse_naive_mean = mean(rmse_naive),
    rmse_naive_se = sd(rmse_naive),
    rmse_naive_ucl = rmse_naive_mean + 1.96 * rmse_naive_se,
    rmse_naive_lcl = rmse_naive_mean - 1.96 * rmse_naive_se,
    rmse_at_k_mean = mean(rmse_at_k),
    rmse_at_k_se = sd(rmse_at_k),
    rmse_at_k_ucl = rmse_at_k_mean + 1.96 * rmse_at_k_se,
    rmse_at_k_lcl = rmse_at_k_mean - 1.96 * rmse_at_k_se,
    rmse_true_mean = mean(rmse_true),
    rmse_true_se = sd(rmse_true),
    rmse_true_ucl = rmse_true_mean + 1.96 * rmse_true_se,
    rmse_true_lcl = rmse_true_mean - 1.96 * rmse_true_se
  )

k_plot_df = k_plot_df[complete.cases(k_plot_df),]


make_k_plot = function(k_plot_df, graph, deg, epsilon_sd, title) {
  p = k_plot_df %>% filter(graph_type==graph,
                           mean_deg==deg,
                           epsilon_dist_sd==epsilon_sd) %>%
    mutate(rmse_naive_hline = rmse_naive_mean[which(k == 150)],
           rmse_true_hline = rmse_true_mean[which(k == 150)]) %>%
    ggplot(.) +
    geom_errorbar(aes(x=k,
                      y=rmse_at_k_mean,
                      ymax=rmse_at_k_ucl,
                      ymin=rmse_at_k_lcl,
                      color='our model RMSE')) +
    geom_hline(aes(yintercept=rmse_naive_hline, color='naive RMSE')) +
    geom_hline(aes(yintercept=rmse_true_hline, color='true RMSE')) +
    labs(title=title) +
    lims(y=c(0, 3.5)) +
    theme_bw()
  return(p)
}

make_k_plot(k_plot_df, 'plc', 12, 1, 'PLC first k RMSE')
make_k_plot(k_plot_df, 'ws', 12, 1, 'WS first k RMSE')






k_plot_df %>% filter(graph_type=='plc',
                     mean_deg==12,
                     epsilon_dist_sd==1) %>%
  mutate(rmse_naive_hline = rmse_naive_mean[which(k == 150)],
         rmse_true_hline = rmse_true_mean[which(k == 150)]) %>%
  ggplot(.) +
  geom_errorbar(aes(x=k,
                    y=rmse_at_k_mean,
                    ymax=rmse_at_k_ucl,
                    ymin=rmse_at_k_lcl,
                    color='our model RMSE'))
