library(ggplot2)
library(reshape)
library(dplyr)

PATH = '/Users/g/Drive/projects-current/project-thresholds/data/one_off_df.csv'

df_rmse = read.csv(PATH)

df_summary = df_rmse %>%
  group_by(activated, exposure) %>%
  summarize(count = n())

df_activated = df_summary[df_summary$activated == 1,]
df_unactivated = df_summary[df_summary$activated == 0,]

df_plot = df_activated %>%
  left_join(df_unactivated, by="exposure") %>%
  ungroup() %>%
  filter(exposure <= 10) %>%
  group_by(exposure) %>%
  mutate(total = count.x + count.y) %>%
  summarize(p = count.x / total,
            lcl = binom.test(count.x, total)$conf.int[1],
            ucl = binom.test(count.x, total)$conf.int[2])

df_plot = as.data.frame(df_plot)
df_rmse_plot = df_rmse[df_rmse$exposure <= 10,]

p1 = ggplot() +
  guides(color=FALSE) +
  expand_limits(y=c(-0.2,1.2)) +
  scale_y_continuous(breaks=c(0,1)) +
  scale_x_continuous(breaks=seq(0,10)) +
  theme_bw() +
  geom_jitter(data=df_rmse_plot,
              aes(x=exposure,
                  y=activated,
                  color='blue'), 
              height=0.15,
              width=0.1) +
  geom_point(data=df_plot, aes(x=exposure, y=p, color='red')) +
  geom_errorbar(data=df_plot,
                aes(x=exposure, ymax=ucl, ymin=lcl, color='red'),
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