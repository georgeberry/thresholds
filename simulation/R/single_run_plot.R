library(ggplot2)
library(dplyr)
library(xtable)

PATH = '/Users/g/Drive/project-thresholds/data/one_off_df.csv'

df_rmse = read.csv(PATH)

df_summary = df_rmse %>%
  group_by(activated, after_activation_alters) %>%
  summarize(count = n())

df_activated = df_summary[df_summary$activated == 1,]
df_unactivated = df_summary[df_summary$activated == 0,]

df_plot = df_activated %>%
  left_join(df_unactivated, by="after_activation_alters") %>%
  ungroup() %>%
  filter(after_activation_alters <= 10) %>%
  group_by(after_activation_alters) %>%
  mutate(total = count.x + count.y) %>%
  summarize(p = count.x / total)
            # lcl = binom.test(count.x, total)$conf.int[1],
            # ucl = binom.test(count.x, total)$conf.int[2])

df_plot = as.data.frame(df_plot)
df_rmse_plot = df_rmse[df_rmse$after_activation_alters <= 10,]

p1 = ggplot() +
  guides(color=FALSE) +
  expand_limits(y=c(-0.2,1.2)) +
  scale_y_continuous(breaks=c(0,1)) +
  scale_x_continuous(breaks=seq(0,10)) +
  theme_bw() +
  geom_jitter(data=df_rmse_plot,
              aes(x=after_activation_alters,
                  y=activated,
                  color='blue'),
              height=0.15,
              width=0.1) +
  geom_point(data=df_plot, aes(x=after_activation_alters, y=p, color='red')) +
  geom_errorbar(data=df_plot,
                aes(x=after_activation_alters, ymax=ucl, ymin=lcl, color='red'),
                width=0.2)



#### randomzied control trial world ###########################################

# people have a threshold, and an observation for each value below their threshold
# plus the threshold itself

IDEAL_PATH = '/Users/g/Drive/projects-current/project-thresholds/data/one_off_ideal_df.csv'

df_ideal = read.csv(IDEAL_PATH)

df_summary_ideal = df_ideal %>%
  group_by(activated, exposure) %>%
  summarize(count = n())

df_activated_ideal = df_summary_ideal[df_summary_ideal$activated == 1,]
df_unactivated_ideal = df_summary_ideal[df_summary_ideal$activated == 0,]

df_plot_ideal = df_activated_ideal %>%
  left_join(df_unactivated_ideal, by="exposure") %>%
  ungroup() %>%
  filter(exposure <= 10) %>%
  group_by(exposure) %>%
  mutate(total = count.x + count.y) %>%
  summarize(p = count.x / total,
            lcl = binom.test(count.x, total)$conf.int[1],
            ucl = binom.test(count.x, total)$conf.int[2])

df_plot_ideal = as.data.frame(df_plot_ideal)
df_rmse_ideal = df_ideal[df_ideal$exposure <= 10,]


dodge = position_dodge(width=4)

ggplot() +
  expand_limits(y=c(-0.2,1.2)) +
  scale_y_continuous(breaks=c(0,1)) +
  scale_x_continuous(breaks=seq(0,10)) +
  theme_bw() +
  geom_jitter(data=df_rmse_ideal,
              aes(x=exposure,
                  y=activated,
                  color='Exposures'),
              height=0.15,
              width=0.1) +
  geom_point(data=df_plot_ideal, aes(x=exposure, y=p, color='Correct')) +
  geom_errorbar(data=df_plot_ideal,
                aes(x=exposure, ymax=ucl, ymin=lcl, color='Correct'),
                width=0.2) +
  geom_point(data=df_plot, aes(x=exposure, y=p, color='Naive')) +
  geom_errorbar(data=df_plot,
                aes(x=exposure, ymax=ucl, ymin=lcl, color='Naive'),
                width=0.2) +
  labs(title='Differences in activation probability estimates')

ggplot() +
  expand_limits(y=c(-0.2,1.2)) +
  scale_y_continuous(breaks=c(0,1)) +
  scale_x_continuous(breaks=seq(0,10)) +
  theme_bw() +
  geom_point(data=df_plot_ideal, aes(x=exposure, y=p, color='Correct')) +
  geom_errorbar(data=df_plot_ideal,
                aes(x=exposure, ymax=ucl, ymin=lcl, color='Correct'),
                width=0.2) +
  geom_point(data=df_plot, aes(x=exposure, y=p, color='Naive')) +
  geom_errorbar(data=df_plot,
                aes(x=exposure, ymax=ucl, ymin=lcl, color='Naive'),
                width=0.2) +
  labs(title='Differences in activation probability estimates')

#### diagnostic plots #########################################################

df_rmse %>%
  group_by(epsilon) %>%
  summarize(threshold=median(threshold)) %>%
  ungroup() %>%
  mutate(threshold=ceiling(threshold)) %>%
  group_by(threshold) %>%
  summarize(count = n()) %>%
  mutate(cumsum=1000 - lag(cumsum(count), default=0)) %>%
  mutate(p=count / cumsum) %>%
  ggplot(.) +
    geom_point(aes(x=threshold, y=p * 1000)) +
    geom_point(aes(x=threshold, y=count, color='activated at step')) +
    geom_point(aes(x=threshold, y=1000-cumsum, color='total active'))


df_rmse %>%
  group_by(epsilon) %>%
  summarize(threshold=median(threshold), count=1) %>%
  ungroup() %>%
  arrange(threshold) %>%
  mutate(cumsum=cumsum(count)) %>%
  ggplot(.) +
  geom_point(aes(x=threshold, y=cumsum))

df_rmse %>%
  group_by(epsilon) %>%
  summarize(threshold=median(threshold)) %>%
  ungroup() %>%
  mutate(threshold=ceiling(threshold)) %>%
  group_by(threshold) %>%
  summarize(count=n()) %>%
  mutate(cumsum=cumsum(count)) %>%
  ggplot(.) +
  geom_point(aes(x=threshold, y=cumsum))


#### one run summary plots ####################################################


PATH = '/Users/g/Drive/projects-current/project-thresholds/data/one_off_sim.csv'

df_sim = read.csv(PATH)
df_sim$threshold_ceil = ceiling(df_sim$threshold)

df_sim$correct = (df_sim$after_activation_alters - df_sim$before_activation_alters == 1)
df_sim$correct = df_sim$correct & df_sim$threshold_ceil > 0

sum(df_sim$correct, na.rm=TRUE)

p2 = ggplot() +
  theme_bw() +
  theme(axis.ticks=element_blank(),
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank()) +
  geom_histogram(data=df_sim,
                 alpha=0.18,
                 binwidth=1.0,
                 aes(x=after_activation_alters,
                     color='Measured',
                     fill='Measured')) +
  geom_histogram(data=df_sim,
                 alpha=0.0,
                 binwidth=1.0,
                 aes(x=threshold,
                     color='True',
                     fill='True')) +
  scale_color_manual(values=c('Measured'='grey80', 'True'='black'),
                     guide=FALSE) +
  scale_fill_manual(values=c('Measured'='grey35', 'True'='white'),
                    guide=FALSE) +
  labs(x='Threshold', y='Count') +
  geom_rug(data=df_sim,
           position='jitter',
           alpha=0.4,
           sides='b',
           aes(y=1, x=after_activation_alters))

ggsave("/Users/g/Documents/real_vs_measured.png",
       p2,
       width=7,
       height=3)

df_correct = df_sim %>%
  filter(correct == TRUE, after_activation_alters > 0)

p3 = ggplot() +
  theme_bw() +
  theme(axis.ticks=element_blank(),
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank()) +
  geom_histogram(data=df_correct,
                 binwidth=1.0,
                 alpha=0.18,
                 aes(x=threshold, fill='Correct', color='Correct')) +
  geom_histogram(data=df_sim,
                 binwidth=1.0,
                 alpha=0.0,
                 aes(x=threshold, fill='All', color='All')) +
  scale_color_manual(values=c('Correct'='grey80', 'All'='black'),
                     guide=FALSE) +
  scale_fill_manual(values=c('Correct'='grey35', 'All'='white'),
                    guide=FALSE) +
  labs(x='Threshold', y='Count')

ggsave("/Users/g/Documents/real_vs_correctly_measured.png",
       p3,
       width=5,
       height=3)

#### matrix of transitions #####################################################

df_activated = df_sim[!is.na(df_sim$after_activation_alters),]

transitions = data.frame(true=ifelse(df_activated$threshold_ceil >= 0,
                                     df_activated$threshold_ceil,
                                     0),
                         plus=df_activated$after_activation_alters -
                              df_activated$threshold_ceil)

transition_table = table(transitions)
xtable(transition_table)

xtable(transitions %>% group_by(plus) %>% summarize(count=n()))

#### true vs predicted distribution ###########################################

ols_mod = lm(after_activation_alters ~ var1, df_correct)
act_mod = lm(after_activation_alters ~ var1, df_sim[df_sim$activated ==1,])
true_mod = lm(threshold_ceil ~ var1, df_sim)
df_sim$pred = predict(ols_mod, df_sim)
df_sim$act_pred = predict(act_mod, df_sim)
df_sim$true_pred = predict(true_mod, df_sim)

ggplot(data=df_sim) +
  geom_histogram(aes(x=threshold, fill='True', color='True'),
                 alpha=0.1,
                 binwidth=1) +
  #geom_histogram(aes(x=pred, fill='Estimated', color='Estimated'),
  #               alpha=0.1,
  #               binwidth=1) +
  #geom_histogram(aes(x=act_pred, fill='Activated', color='Activated'),
  #               alpha=0.1,
  #               binwidth=1) +
  geom_histogram(aes(x=true_pred, fill='True model', color='True model'),
                 alpha=0.1,
                 binwidth=1) +
  theme_bw()
