library(data.table)
library(ggplot2)
library(dplyr)

PATH = '/Users/g/Drive/project-thresholds/thresholds/data/count_df.csv'
df = fread(PATH) %>%
  filter(graph_type=='plc', epsilon_dist_sd==1.0) %>%
  mutate(after_activation_alters = ifelse(
           after_activation_alters > 40, 40, after_activation_alters),
         measurement_error = ifelse(
           measurement_error > 25, 25, measurement_error))

#### make data #################################################################

thresh_df = df %>%
  group_by(threshold) %>%
  summarize(thresh_count = n()) %>%
  mutate(thresh_density = thresh_count / sum(thresh_count))

exposure_df = df %>%
  filter(!is.na(after_activation_alters)) %>%
  group_by(after_activation_alters) %>%
  summarize(exposure_count = n()) %>%
  mutate(exposure_density = exposure_count / sum(exposure_count))

error_df = df %>%
  filter(!is.na(measurement_error)) %>%
  group_by(measurement_error) %>%
  summarize(error_count = n()) %>%
  mutate(error_density = error_count / sum(error_count))

cm_df = df %>%
  group_by(threshold) %>%
  summarize(thresh_count = n(),
            cm_count = sum(observed)) %>%
  mutate(thresh_frac = thresh_count / sum(thresh_count),
         cm_frac = cm_count / sum(thresh_count))

ws_thresh_df = ws_df %>%
  group_by(threshold) %>%
  summarize(thresh_count = n()) %>%
  mutate(thresh_density = thresh_count / sum(thresh_count))

ws_exposure_df = ws_df %>%
  filter(!is.na(after_activation_alters)) %>%
  group_by(after_activation_alters) %>%
  summarize(exposure_count = n()) %>%
  mutate(exposure_density = exposure_count / sum(exposure_count))


# hist
ggplot() +
  geom_histogram(data=thresh_df,
                 alpha=0.0,
                 aes(x=threshold,
                     y=thresh_density,
                     color='True'),
                 stat="identity") +
  geom_histogram(data=exposure_df,
                 alpha=0.0,
                 aes(x=after_activation_alters,
                     y=exposure_density,
                     color='Exposure'),
                 stat="identity")

ggplot() +
  theme_bw() +
  geom_density(data=df,
               aes(x=threshold, fill='True', color='True'),
               alpha=0.2,
               adjust=4) +
  geom_density(data=df,
               aes(x=after_activation_alters, fill='Exposure', color='Exposure'),
               alpha=0.2,
               adjust=4)

#### errors #####################################################################

error_at_thresh_df = df %>%
  group_by(threshold) %>%
  summarize(err_at_thresh=mean(measurement_error, na.rm=TRUE))

ggplot() +
  geom_histogram(data=error_df, aes(x=measurement_error, y=error_density), stat="identity")

ggplot() +
  geom_histogram(data=error_at_thresh_df, aes(x=threshold,y=err_at_thresh), stat="identity")

#### testing ####################################################################

t = df %>%
  filter(after_activation_alters <= 15) %>%
  group_by(mean_deg, after_activation_alters) %>%
  summarize(count = n())


df %>%
  filter(!is.na(after_activation_alters)) %>%
  group_by(after_activation_alters, mean_deg) %>%
  summarize(exposure_count = n()) %>%
  group_by(mean_deg) %>%
  mutate(exposure_density = exposure_count / sum(exposure_count)) %>%
ggplot(., aes(x=after_activation_alters, y=exposure_density, color=factor(mean_deg))) +
  geom_line()







ws_df = fread(PATH) %>%
  filter(graph_type=='ws', epsilon_dist_sd==1.0) %>%
  mutate(after_activation_alters = ifelse(
    after_activation_alters > 40, 40, after_activation_alters),
    measurement_error = ifelse(
      measurement_error > 25, 25, measurement_error))

ws_df %>%
  filter(!is.na(after_activation_alters)) %>%
  group_by(after_activation_alters, mean_deg) %>%
  summarize(exposure_count = n()) %>%
  group_by(mean_deg) %>%
  mutate(exposure_density = exposure_count / sum(exposure_count)) %>%
ggplot(., aes(x=after_activation_alters, y=exposure_density, color=factor(mean_deg))) +
  geom_line()


#### plots ######################################################################

# can we incorporate w-s in these plots as well?

# density of True vs Exposure-at-activation-time
p1 = ggplot() +
  theme_bw() +
  theme(axis.ticks=element_blank(),
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        legend.position = c(.95, .95),
        legend.justification = c("right", "top"),
        legend.box.just = "right",
        legend.margin = margin(6, 6, 6, 6)) +
  guides(color = guide_legend(override.aes = list(shape = c(17,15)))) +
  scale_y_continuous(breaks=c(0.0,0.05,0.10,0.15), limits=c(0, 0.15)) +
  labs(x='Threshold',
       y='Proportion',
       color=element_blank()) +
  geom_line(data=thresh_df,
            aes(x=threshold,
                y=thresh_density,
                color='True'),
            stat="identity") +
  geom_point(data=thresh_df,
            aes(x=threshold,
                y=thresh_density,
                color='True'),
            shape=15,
            size=1) +
  geom_line(data=exposure_df,
            aes(x=after_activation_alters,
                y=exposure_density,
                color='Exposure at\nactivation'),
            stat="identity") +
  geom_point(data=exposure_df,
            aes(x=after_activation_alters,
                y=exposure_density,
                color='Exposure at\nactivation'),
            shape=17,
            size=1)

ggsave('p1.pdf', p1, device = "pdf", path='/Users/g/Desktop',
       height=4, width=6)

p2 = ggplot() +
  theme_bw() +
  theme(axis.ticks=element_blank(),
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        legend.position = c(.95, .95),
        legend.justification = c("right", "top"),
        legend.box.just = "right",
        legend.margin = margin(6, 6, 6, 6)) +
  guides(color = guide_legend(override.aes = list(shape = c(17,15)))) +
  scale_y_continuous(breaks=c(0.0,0.05,0.10,0.15), limits=c(0, 0.15)) +
  labs(x='Threshold',
       y='Proportion',
       color=element_blank()) +
  geom_line(data=cm_df,
            aes(x=threshold,
                y=cm_frac,
                color='Correctly\nmeasured'),
            stat="identity") +
  geom_point(data=cm_df,
             aes(x=threshold,
                 y=cm_frac,
                 color='Correctly\nmeasured'),
             shape=17,
             size=1) +
  geom_line(data=cm_df,
            aes(x=threshold,
                y=thresh_frac,
                color='True'),
            stat="identity") +
  geom_point(data=cm_df,
             aes(x=threshold,
                 y=thresh_frac,
                 color='True'),
             shape=15,
             size=1)

ggsave('p2.pdf', p2, device = "pdf", path='/Users/g/Desktop',
       height=4, width=6)



# ws #

ggplot() +
  theme_bw() +
  theme(axis.ticks=element_blank(),
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        legend.position = c(.95, .95),
        legend.justification = c("right", "top"),
        legend.box.just = "right",
        legend.margin = margin(6, 6, 6, 6)) +
  guides(color = guide_legend(override.aes = list(shape = c(17,15)))) +
  scale_y_continuous(breaks=c(0.0,0.05,0.10,0.15), limits=c(0, 0.15)) +
  labs(x='Threshold',
       y='Proportion',
       color=element_blank()) +
  geom_line(data=ws_thresh_df,
            aes(x=threshold,
                y=thresh_density,
                color='True'),
            stat="identity") +
  geom_point(data=ws_thresh_df,
             aes(x=threshold,
                 y=thresh_density,
                 color='True'),
             shape=15,
             size=1) +
  geom_line(data=ws_exposure_df,
            aes(x=after_activation_alters,
                y=exposure_density,
                color='Exposure at\nactivation'),
            stat="identity") +
  geom_point(data=ws_exposure_df,
             aes(x=after_activation_alters,
                 y=exposure_density,
                 color='Exposure at\nactivation'),
             shape=17,
             size=1)
