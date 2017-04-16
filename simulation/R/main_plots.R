library(ggplot2)
library(reshape)
library(dplyr)
library(data.table)

RMSE_PATH = '/Users/g/Drive/project-thresholds/thresholds/data/sim_rmse_df.csv'
K_PATH = '/Users/g/Drive/project-thresholds/thresholds/data/sim_k_df.csv'

#### diagnostics ##############################################################

df_rmse = fread(RMSE_PATH)

df_rmse %>%
  filter(graph_type=='plc', mean_deg==12, epsilon_dist_sd==1.0) %>%
  summarize(activated=mean(num_activated),
            measured=mean(num_measured),
            measured_sd=sd(num_measured),
            count=n())

#### RMSE processing ##########################################################
# The following variables are important
# - rmse_measured_ols
# - rmse_true
# - rmse_activated_ols
# - rmse_activated_naive

df_rmse = fread(RMSE_PATH)

m = melt(df_rmse,
         measure.vars=c('rmse_measured_ols',
                        'rmse_true',
                        'rmse_activated_ols',
                        'rmse_activated_naive',
                        'rmse_activated_activated',
                        'rmse_measured_activated'),
         id.vars=c('graph_type', 'mean_deg', 'epsilon_dist_sd'))

#### another take on RMSE plots ################################################

mm = m %>%
  filter(variable != 'rmse_true')
mm$variable = ordered(factor(mm$variable),
                      levels=c('rmse_measured_ols',
                               'rmse_activated_ols',
                               'rmse_activated_naive',
                               'rmse_activated_activated',
                               'rmse_measured_activated'),
                      labels=c('Measured',
                               'Activated',
                               'Naive',
                               'act2',
                               'meas2'))

p3 = mm %>%
  filter(epsilon_dist_sd==1.0, graph_type=='plc', !variable %in% c('act2', 'meas2')) %>%
  ggplot(.) +
    geom_boxplot(aes(y=value,
                    x=factor(mean_deg),
                    fill=variable),
                # scale="width",
                position=position_dodge(width=0.6),
                alpha=0.4) +
    geom_hline(aes(yintercept=1, color='True RMSE'), linetype='dashed') +
    labs(x='Mean degree', y='Root mean squared error') +
    scale_y_continuous(breaks=c(0,2,4,6,8,10), limits=c(0,10)) +
    theme_bw() +
    scale_color_manual(values=c("True RMSE"="black")) +
    guides(color=guide_legend(title=NULL), fill=guide_legend(title='Category'))

ggsave("/Users/g/Desktop/p3.pdf",
       p3,
       device="pdf",
       width=6,
       height=4)

#### k-df processing ###########################################################

df_k = fread(K_PATH)

p4 = df_k %>%
  filter(graph_type=='plc', mean_deg==12, epsilon_dist_sd==1, k<=100) %>%
  ungroup() %>%
  ggplot(.) +
    geom_boxplot(aes(x=factor(k), y=rmse_at_k)) +
    geom_hline(aes(yintercept=mean(rmse_naive), color='Naive RMSE'), linetype='dashed') +
    geom_hline(aes(yintercept=mean(rmse_true), color='True RMSE'), linetype='dashed') +
    lims(y=c(0,5.5)) +
    theme_bw() +
    guides(color=guide_legend(title='Benchmarks')) +
    labs(x='First k correctly measured', y='Root mean squared error')

ggsave("/Users/g/Desktop/p4.pdf",
       p4,
       device="pdf",
       height=4,
       width=6)

p5 = df_k %>%
  filter(graph_type=='plc', mean_deg==12, epsilon_dist_sd==1, k<=100) %>%
  ungroup() %>%
    ggplot(.) +
  geom_boxplot(aes(x=factor(k), y=num_activated)) +
    lims(y=c(0,850)) +
    theme_bw() +
    labs(x='First k correctly measured', y='Total activations')

ggsave("/Users/g/Desktop/p5.pdf",
       p5,
       device="pdf",
       height=4,
       width=6)
