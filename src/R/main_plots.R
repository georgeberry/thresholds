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
                                         'rmse_activated_naive'),
                                labels=c('True',
                                         'Measured',
                                         'Activated',
                                         'Naive'))

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
    theme(axis.title.x=element_blank()) +
    scale_y_continuous(limits=c(0, 9), breaks=c(0,2,4,6,8))
  return(p)
}

p1 = make_rmse_plot(rmse_plot_df, 'plc', 1, 'Power-law RMSE')
make_rmse_plot(rmse_plot_df, 'ws', 1, 'Watts-Strogatz RMSE')

#### another take on RMSE plots ################################################

mm = m
mm$variable = ordered(factor(mm$variable),
                      levels=c('rmse_true',
                               'rmse_measured_ols',
                               'rmse_activated_ols',
                               'rmse_activated_naive'),
                      labels=c('True',
                               'Measured',
                               'Activated',
                               'Naive'))

p2 = mm %>%
  filter(epsilon_dist_sd==1.0, graph_type=='plc') %>%
  ggplot(.) +
    geom_violin(aes(y=value,
                    x=factor(mean_deg),
                    color=variable),
               position=position_dodge(width=0.4),
               alpha=0.4) +
    scale_shape(solid=FALSE) +
    geom_hline(yintercept=1, linetype='dashed') +
    labs(x='Mean degree', y='Root mean squared error') +
    scale_y_continuous(breaks=c(0,2,4,6,8,10), limits=c(0,10)) +
    theme_bw()

#### k-df processing ###########################################################

df_k = read.csv(K_PATH)

p4 = df_k %>%
  filter(graph_type=='plc', mean_deg==12, epsilon_dist_sd==1, k<=100) %>%
  ungroup() %>%
  ggplot(.) +
    geom_violin(aes(x=factor(k), y=rmse_at_k)) +
    geom_hline(aes(yintercept=mean(rmse_naive), color='Naive RMSE')) +
    geom_hline(aes(yintercept=mean(rmse_true), color='True RMSE')) +
    lims(y=c(0,5.5)) +
    theme_bw()
    
p5 =df_k %>%
  filter(graph_type=='plc', mean_deg==12, epsilon_dist_sd==1, k<=100) %>%
  ungroup() %>%
    ggplot(.) +
  geom_violin(aes(x=factor(k), y=num_activated)) +
    lims(y=c(0,850)) +
    theme_bw()

