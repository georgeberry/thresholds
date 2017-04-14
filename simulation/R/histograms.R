library(data.table)
library(ggplot2)
library(dplyr)

PATH = '/Users/g/Drive/project-thresholds/thresholds/data/count_df.csv'
df = fread(PATH) %>%
  filter(graph_type=='plc', epsilon_dist_sd==1.0) %>%
  mutate(after_activation_alters = ifelse(
           after_activation_alters > 40, 41, after_activation_alters),
         measurement_error = ifelse(
           measurement_error > 25, 26, measurement_error))

#### density of true vs expsoure-at-activation #################################

ggplot() +
  geom_density(data=df,
               aes(threshold),
               adjust=5) +
  geom_density(data=df,
               aes(after_activation_alters),
               adjust=5)

#### true vs exposure ###########################################################

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

# density
ggplot() +
  theme_bw() +
  geom_line(data=thresh_df,
            aes(x=threshold,
                y=thresh_density,
                color='True'),
            stat="identity") +
  geom_line(data=exposure_df,
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

#### correct measurement ########################################################

cm_df = df %>%
  group_by(threshold) %>%
  summarize(thresh_count = n(),
            cm_count = sum(observed)) %>%
  mutate(thresh_frac = thresh_count / sum(thresh_count),
         cm_frac = cm_count / sum(thresh_count))

ggplot() +
  geom_line(data=cm_df,
            aes(x=threshold,
                y=thresh_frac,
                color='True'),
            stat="identity") +
  geom_line(data=cm_df,
            aes(x=threshold,
                y=cm_frac,
                color='CM'),
            stat="identity")
