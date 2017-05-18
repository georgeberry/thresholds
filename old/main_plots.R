library(ggplot2)
library(reshape)
library(dplyr)
library(data.table)

RMSE_PATH = '/Users/g/Drive/project-thresholds/thresholds/data/sim_rmse_df.csv'
K_PATH = '/Users/g/Drive/project-thresholds/thresholds/data/sim_k_df.csv'

#### diagnostics ##############################################################

df_rmse = fread(RMSE_PATH)

df_rmse %>%
  filter(graph_type=='plc', mean_deg==16, epsilon_dist_sd==1.0) %>%
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
                               'Active',
                               'Naive',
                               'act2',
                               'meas2'))

p3_df = mm %>%
  filter(epsilon_dist_sd==1.0, graph_type=='plc', !variable %in% c('act2', 'meas2')) 


p3 = p3_df %>%
  ggplot(.) +
    theme_bw() +
    theme(axis.ticks=element_blank(),
          panel.grid.major = element_blank(),
          panel.grid.minor = element_blank(),
          legend.position = c(.22, .96),
          legend.justification = c("right", "top"),
          legend.box.just = "right",
          legend.margin = margin(6, 6, 6, 6)) +
    geom_hline(aes(yintercept=1), linetype='dashed', alpha=0.8) +
    geom_violin(aes(y=value,
                    x=factor(mean_deg),
                    color=variable,
                    fill=variable),
                scale="area",
                position=position_dodge(width=0.5),
                alpha=0.1,
                lwd=0.4) +
    scale_color_manual(values=c('#00BFC4', '#C77CFF', '#F8766D')) +
    scale_fill_manual(values=c('#00BFC4', '#C77CFF', '#F8766D')) +
    stat_summary(aes(y=value,
                     x=factor(mean_deg),
                     color=variable),
                 fun.y="mean",
                 geom="point",
                 position=position_dodge(width=0.5),
                 shape=3) +
    labs(x='Mean degree', y='RMSE predicting threshold') +
    scale_y_continuous(breaks=c(0,2,4,6,8,10), limits=c(0,10.5)) +
    guides(color=guide_legend(title="Method"),
           fill=guide_legend(title="Method"))

ggsave("/Users/g/Desktop/p3.pdf",
       p3,
       device="pdf",
       width=5.5,
       height=3.5)

#### k-df processing ###########################################################

df_k = fread(K_PATH)

p4 = df_k %>%
  filter(graph_type=='plc', mean_deg==16, epsilon_dist_sd==1, k<=100) %>%
  ungroup() %>%
  ggplot(.) +
    theme_bw() +
    theme(axis.ticks=element_blank(),
          panel.grid.major = element_blank(),
          panel.grid.minor = element_blank(),
          legend.position = c(.95, .95),
          legend.justification = c("right", "top"),
          legend.box.just = "right",
          legend.margin = margin(6, 6, 6, 6)) +
    geom_hline(aes(yintercept=mean(rmse_naive), color='Naive RMSE'), linetype='dashed') +
    geom_hline(aes(yintercept=mean(rmse_true), color='True RMSE'), linetype='dashed') +
    stat_boxplot(aes(x=factor(k), y=rmse_at_k), geom = "errorbar", width = 0.2, lwd=0.3) +
    geom_boxplot(aes(x=factor(k), y=rmse_at_k), width=.4, outlier.size=.4, lwd=0.4) +
    lims(y=c(0,5)) +
    guides(color=guide_legend(title='Benchmarks')) +
    labs(x='First k correctly measured', y='RMSE predicting threshold')

ggsave("/Users/g/Desktop/p4.pdf",
       p4,
       device="pdf",
       width=6,
       height=4)

p5 = df_k %>%
  filter(graph_type=='plc', mean_deg==12, epsilon_dist_sd==1, k<=100) %>%
  ungroup() %>%
    ggplot(.) +
  stat_boxplot(aes(x=factor(k), y=num_activated), geom = "errorbar", width = 0.2, lwd=0.3) +
  geom_boxplot(aes(x=factor(k), y=num_activated), width=.4, outlier.size=.4, lwd=0.4) +
    lims(y=c(0,850)) +
    theme_bw() +
    labs(x='First k correctly measured', y='Total activations')

ggsave("/Users/g/Desktop/p5.pdf",
       p5,
       device="pdf",
       width=6,
       height=4)

