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

#### another take on RMSE plots ################################################

mm = m %>%
  filter(variable != 'rmse_true')
mm$variable = ordered(factor(mm$variable),
                      levels=c('rmse_measured_ols',
                               'rmse_activated_ols',
                               'rmse_activated_naive'),
                      labels=c('Measured',
                               'Activated',
                               'Naive'))

p2 = mm %>%
  filter(epsilon_dist_sd==1.0, graph_type=='plc') %>%
  ggplot(.) +
    geom_violin(aes(y=value,
                    x=factor(mean_deg),
                    fill=variable),
                scale="width",
                position=position_dodge(width=0.6),
                alpha=0.4) +
    scale_shape(solid=FALSE) +
    geom_hline(aes(yintercept=1, color='True RMSE'), linetype='dashed') +
    labs(x='Mean degree', y='Root mean squared error') +
    scale_y_continuous(breaks=c(0,2,4,6,8,10), limits=c(0,10)) +
    theme_bw() +
    scale_color_manual(values=c("True RMSE"="black")) +
    guides(color=guide_legend(title=NULL), fill=guide_legend(title='Category'))

ggsave("/Users/g/Documents/rmse_by_degree.png",
       p2,
       width=7,
       height=3)

#### k-df processing ###########################################################

df_k = read.csv(K_PATH)

p3 = df_k %>%
  filter(graph_type=='plc', mean_deg==12, epsilon_dist_sd==1, k<=100) %>%
  ungroup() %>%
  ggplot(.) +
    geom_violin(aes(x=factor(k), y=rmse_at_k)) +
    geom_hline(aes(yintercept=mean(rmse_naive), color='Naive RMSE')) +
    geom_hline(aes(yintercept=mean(rmse_true), color='True RMSE'), linetype='dashed') +
    lims(y=c(0,5.5)) +
    theme_bw() +
    guides(color=guide_legend(title='Benchmarks')) +
    labs(x='First k correctly measured', y='Root mean squared error')

ggsave("/Users/g/Documents/model_vs_true.png",
       p3,
       height=3,
       width=7)

p4 = df_k %>%
  filter(graph_type=='plc', mean_deg==12, epsilon_dist_sd==1, k<=100) %>%
  ungroup() %>%
    ggplot(.) +
  geom_violin(aes(x=factor(k), y=num_activated)) +
    lims(y=c(0,850)) +
    theme_bw() +
    labs(x='First k correctly measured', y='Total activations')

ggsave("/Users/g/Documents/num_activated_at_first_k.png",
       p4,
       height=3,
       width=7)
