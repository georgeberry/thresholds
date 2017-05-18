library(data.table)
library(dplyr)
library(ggplot2)
library(grid)
library(grImport)
library(reshape)

#### simulation plots ##########################################################

COUNT_DF_PATH = '/Users/g/Drive/project-thresholds/thresholds/data/count_df.csv'
count_df = fread(COUNT_DF_PATH) %>%
  filter(graph_type=='plc', epsilon_dist_sd==1.0, mean_deg==16) %>%
  mutate(after_activation_alters = ifelse(
    after_activation_alters > 40, 40, after_activation_alters),
    measurement_error = ifelse(
      measurement_error > 25, 25, measurement_error))

thresh_df = count_df %>%
  group_by(threshold) %>%
  summarize(thresh_count = n()) %>%
  mutate(thresh_density = thresh_count / sum(thresh_count))

exposure_df = count_df %>%
  filter(!is.na(after_activation_alters)) %>%
  group_by(after_activation_alters) %>%
  summarize(exposure_count = n()) %>%
  mutate(exposure_density = exposure_count / sum(exposure_count))

error_df = count_df %>%
  filter(!is.na(measurement_error)) %>%
  group_by(measurement_error) %>%
  summarize(error_count = n()) %>%
  mutate(error_density = error_count / sum(error_count))

cm_df = count_df %>%
  group_by(threshold) %>%
  summarize(thresh_count = n(),
            cm_count = sum(observed)) %>%
  mutate(thresh_frac = thresh_count / sum(thresh_count),
         cm_frac = cm_count / sum(thresh_count))

#### plots #####################################################################

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
  scale_y_continuous(breaks=c(0.0,0.05,0.10,0.15), limits=c(0, 0.175)) +
  labs(x='Threshold',
       y='Density',
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
       height=2.5, width=5)

# True vs correctly measured
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
       y='Density',
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
       height=2.5, width=5)

#### RMSE processing ###########################################################

RMSE_PATH = '/Users/g/Drive/project-thresholds/thresholds/data/sim_rmse_df.csv'

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

# violin plot of rmse
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

#### small graph plots #########################################################

PostScriptTrace("/Users/g/Documents/G3.ps", "/Users/g/Documents/G3.xml")
PostScriptTrace("/Users/g/Documents/G6.ps", "/Users/g/Documents/G6.xml")
PostScriptTrace("/Users/g/Documents/G7.ps", "/Users/g/Documents/G7.xml")
PostScriptTrace("/Users/g/Documents/G13.ps", "/Users/g/Documents/G13.xml")
PostScriptTrace("/Users/g/Documents/G14.ps", "/Users/g/Documents/G14.xml")
PostScriptTrace("/Users/g/Documents/G15.ps", "/Users/g/Documents/G15.xml")
PostScriptTrace("/Users/g/Documents/G16.ps", "/Users/g/Documents/G16.xml")
PostScriptTrace("/Users/g/Documents/G17.ps", "/Users/g/Documents/G17.xml")
PostScriptTrace("/Users/g/Documents/G18.ps", "/Users/g/Documents/G18.xml")

# read xml
pics <- list(G3 = readPicture("/Users/g/Documents/G3.xml"),
             G6 = readPicture("/Users/g/Documents/G6.xml"),
             G7 = readPicture("/Users/g/Documents/G7.xml"),
             G13 = readPicture("/Users/g/Documents/G13.xml"),
             G14 = readPicture("/Users/g/Documents/G14.xml"),
             G15 = readPicture("/Users/g/Documents/G15.xml"),
             G16 = readPicture("/Users/g/Documents/G16.xml"),
             G17 = readPicture("/Users/g/Documents/G17.xml"),
             G18 = readPicture("/Users/g/Documents/G18.xml"))

df = fread('/Users/g/Desktop/small_graphs.tsv', sep='\t') %>%
  mutate(always_some_wrong=factor(ifelse(all_correct == 0,
                                        'At least one node always mismeasured',
                                        'All nodes sometimes correctly measured')))

df$name = factor(df$name)
df$name = relevel(df$name, 'G7')
df$name = relevel(df$name, 'G6')
df$name = relevel(df$name, 'G3')

g = df %>%
  ggplot(.) +
  theme_bw() +
  theme(panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        axis.text.x=element_blank(),
        axis.ticks.y=element_blank(),
        legend.position = c(.5, .25),
        legend.justification = c("right", "top"),
        legend.box.just = "right",
        legend.margin = margin(6, 6, 6, 6)) +
  xlab('\n\n\n') +
  ylab('Proportion correctly measured') +
  geom_point(aes(x=name, y=cm, color=name, shape=always_some_wrong), position=position_jitter(width=0.1)) +
  guides(color=FALSE) +
  scale_y_continuous(expand = c(0, 0), limits = c(0, 1)) +
  scale_shape_manual(values=c(19, 2)) +
  guides(shape=guide_legend(title=element_blank()))

## extract the components of the ggplot
gb   <- ggplot_build(g)
xpos <- gb$layout$panel_ranges[[1]]$x.major
yrng <- gb$layout$panel_ranges[[1]]$y.range

## ensure that the number of pictures to use for labels
## matches the number of x categories
if(length(xpos) != length(pics)) stop("Detected a different number of pictures to x categories")

npoints = length(xpos)

## create a new grob of the images aligned to the x-axis
## at the categorical x positions
my_g <- do.call("grobTree", Map(symbolsGrob, pics, x=xpos, y=-0.9, size=2.5))

## annotate the original ggplot with the new grob
gg <- g + annotation_custom(my_g,
                            xmin = -Inf,
                            xmax =  Inf,
                            ymax = yrng[1] + 0.25*(yrng[2]-yrng[1])/npoints,
                            ymin = yrng[1] - 0.50*(yrng[2]-yrng[1])/npoints)

## turn off clipping to allow plotting outside of the plot area
gg2 <- ggplotGrob(gg)
gg2$layout$clip[gg2$layout$name=="panel"] <- "off"

## produce the final, combined grob
grid.newpage()
grid.draw(gg2)
