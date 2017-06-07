library(data.table)
library(dplyr)
library(ggplot2)
library(grid)
library(grImport)
library(reshape)

#### boilerplate #################################################################

gg_color_hue <- function(n, offset=0) {
  hues = seq(15 + offset, 375 + offset, length = n + 1)
  hcl(h = hues, l = 65, c = 100)[1:n]
}

multiplot <- function(..., plotlist=NULL, file, cols=1, layout=NULL) {
  library(grid)

  # Make a list from the ... arguments and plotlist
  plots <- c(list(...), plotlist)

  numPlots = length(plots)

  # If layout is NULL, then use 'cols' to determine layout
  if (is.null(layout)) {
    # Make the panel
    # ncol: Number of columns of plots
    # nrow: Number of rows needed, calculated from # of cols
    layout <- matrix(seq(1, cols * ceiling(numPlots/cols)),
                    ncol = cols, nrow = ceiling(numPlots/cols))
  }

 if (numPlots==1) {
    print(plots[[1]])

  } else {
    # Set up the page
    grid.newpage()
    pushViewport(viewport(layout = grid.layout(nrow(layout), ncol(layout))))

    # Make each plot, in the correct location
    for (i in 1:numPlots) {
      # Get the i,j matrix positions of the regions that contain this subplot
      matchidx <- as.data.frame(which(layout == i, arr.ind = TRUE))

      print(plots[[i]], vp = viewport(layout.pos.row = matchidx$row,
                                      layout.pos.col = matchidx$col))
    }
  }
}

#### simulation plots ##########################################################

COUNT_DF_PATH = '/Users/g/Drive/project-thresholds/thresholds/data/count_df.csv'
count_df = fread(COUNT_DF_PATH) %>%
  filter(graph_type=='plc', epsilon_dist_sd==1.0) %>%
  mutate(after_activation_alters = ifelse(
    after_activation_alters > 30, 30, after_activation_alters),
    measurement_error = ifelse(
      measurement_error > 25, 25, measurement_error))

count_df %>%
  group_by(mean_deg) %>%
  mutate(act=ifelse(after_activation_alters >= threshold, 1, 0)) %>%
  summarize(tot=n(),
            sum_obs=sum(observed) / 1000,
            sum_act=sum(act, na.rm=T) / 1000) %>%
  mutate(cm_rate = sum_obs/tot,
         act_rate = sum_act/tot)

thresh_df = count_df %>%
  group_by(threshold, mean_deg) %>%
  summarize(thresh_count = n()) %>%
  group_by(mean_deg) %>%
  mutate(thresh_density = thresh_count / sum(thresh_count))

exposure_df = count_df %>%
  filter(!is.na(after_activation_alters)) %>%
  group_by(after_activation_alters, mean_deg) %>%
  summarize(exposure_count = n()) %>%
  group_by(mean_deg) %>%
  mutate(exposure_density = exposure_count / sum(exposure_count))

cm_df = count_df %>%
  group_by(threshold, mean_deg) %>%
  summarize(thresh_count = n(),
            cm_count = sum(observed)) %>%
  group_by(mean_deg) %>%
  mutate(thresh_frac = thresh_count / sum(thresh_count),
         cm_density = cm_count / sum(cm_count)) %>%
  filter(cm_density > 0)

cm_ratio_df = count_df %>%
  group_by(threshold, mean_deg) %>%
  summarize(thresh_count = n(),
            cm_count = sum(observed)) %>%
  group_by(mean_deg) %>%
  mutate(cm_ratio = cm_count / thresh_count)

#### plots #####################################################################

# density of True Distribution vs Exposure-at-activation-time
p1 = ggplot() +
  theme_bw() +
  theme(axis.ticks = element_blank(),
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        legend.position = c(.97, .99),
        legend.justification = c("right", "top"),
        legend.box.just = "right",
        legend.margin = margin(6, 6, 6, 6)) +
  scale_y_continuous(breaks=c(0.0,0.05,0.10,0.15,0.20,0.25,0.30),
                     limits=c(0.00, 0.30)) +
  scale_color_manual(values=c("#619CFF","#00BA38", "#F8766D")) +
  labs(x='Degree = 12',
       y='Density',
       color=element_blank()) +
  geom_line(data=cm_df %>% filter(mean_deg==12),
            aes(x=threshold,
                y=cm_density,
                color='Precisely Measured'),
            stat="identity") +
  geom_point(data=cm_df %>% filter(mean_deg==12),
             aes(x=threshold,
                 y=cm_density,
                 color='Precisely Measured'),
             shape=17,
             size=1) +
  geom_line(data=exposure_df %>% filter(mean_deg==12),
            aes(x=after_activation_alters,
                y=exposure_density,
                color='EAA Rule'),
            stat="identity") +
  geom_point(data=exposure_df %>% filter(mean_deg==12),
             aes(x=after_activation_alters,
                 y=exposure_density,
                 color='EAA Rule'),
             shape=17,
             size=1) +
  geom_line(data=thresh_df %>% filter(mean_deg==12),
            aes(x=threshold,
                y=thresh_density,
                color='True Distribution'),
            stat="identity") +
  geom_point(data=thresh_df %>% filter(mean_deg==12),
             aes(x=threshold,
                 y=thresh_density,
                 color='True Distribution'),
             shape=15,
             size=1)

ggsave('p1.pdf', p1, device = "pdf", path='/Users/g/Desktop',
       height=2.5, width=5)

p2 = ggplot() +
  theme_bw() +
  theme(axis.ticks=element_blank(),
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank()) +
  guides(color = guide_legend(override.aes = list(shape = c(17,15,16)))) +
  scale_y_continuous(breaks=c(0.0,0.05,0.10,0.15,0.20,0.25,0.30),
                     limits=c(0.00, 0.30)) +
  scale_color_manual(values=c("#619CFF","#00BA38", "#F8766D")) +
  labs(x='Degree = 16',
       y='') +
  guides(color=FALSE, shape=FALSE) +
  geom_line(data=cm_df %>% filter(mean_deg==16),
            aes(x=threshold,
                y=cm_density,
                color='Precisely Measured'),
            stat="identity") +
  geom_point(data=cm_df %>% filter(mean_deg==16),
             aes(x=threshold,
                 y=cm_density,
                 color='Precisely Measured'),
             shape=17,
             size=1) +
  geom_line(data=exposure_df %>% filter(mean_deg==16),
            aes(x=after_activation_alters,
                y=exposure_density,
                color='EAA Rule'),
            stat="identity") +
  geom_point(data=exposure_df %>% filter(mean_deg==16),
             aes(x=after_activation_alters,
                 y=exposure_density,
                 color='EAA Rule'),
             shape=17,
             size=1) +
  geom_line(data=thresh_df %>% filter(mean_deg==16),
            aes(x=threshold,
                y=thresh_density,
                color='True Distribution'),
            stat="identity") +
  geom_point(data=thresh_df %>% filter(mean_deg==16),
             aes(x=threshold,
                 y=thresh_density,
                 color='True Distribution'),
             shape=15,
             size=1)

ggsave('p2.pdf', p2, device = "pdf", path='/Users/g/Desktop',
       height=2.5, width=5)

p3 = ggplot() +
  theme_bw() +
  theme(axis.ticks=element_blank(),
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        legend.position = c(.93, .93),
        legend.justification = c("right", "top"),
        legend.box.just = "right",
        legend.margin = margin(6, 6, 6, 6)) +
  guides(color = guide_legend(override.aes = list(shape = c(17,15,16)))) +
  scale_y_continuous(breaks=c(0.0,0.05,0.10,0.15,0.20,0.25,0.30),
                     limits=c(0.00, 0.30)) +
  scale_color_manual(values=c("#619CFF","#00BA38", "#F8766D")) +
  labs(x='Degree = 20',
       y='') +
  guides(color=FALSE, shape=FALSE) +
  geom_line(data=cm_df %>% filter(mean_deg==20),
            aes(x=threshold,
                y=cm_density,
                color='Precisely Measured'),
            stat="identity") +
  geom_point(data=cm_df %>% filter(mean_deg==20),
             aes(x=threshold,
                 y=cm_density,
                 color='Precisely Measured'),
             shape=17,
             size=1) +
  geom_line(data=exposure_df %>% filter(mean_deg==20),
            aes(x=after_activation_alters,
                y=exposure_density,
                color='EAA Rule'),
            stat="identity") +
  geom_point(data=exposure_df %>% filter(mean_deg==20),
             aes(x=after_activation_alters,
                 y=exposure_density,
                 color='EAA Rule'),
             shape=17,
             size=1) +
  geom_line(data=thresh_df %>% filter(mean_deg==20),
            aes(x=threshold,
                y=thresh_density,
                color='True Distribution'),
            stat="identity") +
  geom_point(data=thresh_df %>% filter(mean_deg==20),
             aes(x=threshold,
                 y=thresh_density,
                 color='True Distribution'),
             shape=15,
             size=1)

ggsave('p3.pdf', p3, device = "pdf", path='/Users/g/Desktop',
       height=2.5, width=5)

# 12 by 2.5
multiplot(p1, p2, p3, cols=3)


# True Distribution vs Precisely Measured
p4 = ggplot() +
  theme_bw() +
  theme(axis.ticks=element_blank(),
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        legend.position = c(.31, .95),
        legend.justification = c("right", "top"),
        legend.box.just = "right",
        legend.margin = margin(6, 6, 6, 6)) +
  guides(color = guide_legend(override.aes = list(shape = c(17,15,16)))) +
  scale_y_continuous(breaks=c(0.0,0.05,0.10,0.15,0.20), limits=c(0, 0.25)) +
  scale_color_manual(values=gg_color_hue(3, 90)) +
  labs(x='Threshold',
       y='Proportion Precisely Measured',
       color='Mean degree',
       shape='Mean degree') +
  geom_line(data=cm_ratio_df,
            aes(x=threshold,
                y=cm_ratio,
                color=factor(mean_deg)),
            stat="identity") +
  geom_point(data=cm_ratio_df,
             aes(x=threshold,
                 y=cm_ratio,
                 color=factor(mean_deg),
                 shape=factor(mean_deg)))

ggsave('p2.pdf', p2, device = "pdf", path='/Users/g/Desktop',
       height=2.5, width=5)

#### RMSE processing ###########################################################

RMSE_PATH = '/Users/g/Drive/project-thresholds/thresholds/data/sim_rmse_df.csv'

# The following variables are important
# - rmse_measured_ols
# - rmse_True Distribution
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
                      labels=c('Precisely Measured',
                               'All Active',
                               'EAA Rule',
                               'act2',
                               'meas2'))

# vals
df_rmse %>%
  filter(epsilon_dist_sd == 1.0) %>%
  group_by(graph_type, mean_deg) %>%
  summarize(rmse_true = mean(rmse_true),
            rmse_act = mean(rmse_activated_ols),
            rmse_meas = mean(rmse_measured_ols),
            rmse_eaa = mean(rmse_activated_naive))

p5_df = mm %>%
  filter(epsilon_dist_sd==1.0, graph_type=='plc', !variable %in% c('act2', 'meas2'))

p5_df[!complete.cases(p5_df),]

# violin plot of rmse
p5 = p5_df %>%
  ggplot(.) +
  theme_bw() +
  theme(axis.ticks=element_blank(),
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        legend.position = c(.4, .96),
        legend.justification = c("right", "top"),
        legend.box.just = "right",
        legend.margin = margin(6, 6, 6, 6)) +
  scale_color_manual(values=c("#619CFF","#00BA38", "#F8766D")) +
  scale_fill_manual(values=c("#619CFF","#00BA38", "#F8766D")) +
  geom_hline(aes(yintercept=1), linetype='dashed', alpha=0.8) +
  geom_violin(aes(y=value,
                  x=factor(mean_deg),
                  color=variable,
                  fill=variable),
              scale="area",
              position=position_dodge(width=0.5),
              alpha=0.1,
              lwd=0.4) +
  stat_summary(aes(y=value,
                   x=factor(mean_deg),
                   color=variable),
               fun.y="mean",
               geom="point",
               position=position_dodge(width=0.5),
               shape=3) +
  labs(x='Graph mean degree', y='RMSE predicting threshold') +
  scale_y_continuous(breaks=c(0,2,4,6,8,10)) +# , limits=c(0,10.5)) +
  guides(color=guide_legend(title="Method"),
         fill=guide_legend(title="Method"))

ggsave("/Users/g/Desktop/p5.pdf",
       p5,
       device="pdf",
       width=5,
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
                                        'At least one node always uncertain',
                                        'All nodes sometimes precisely measured')))

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
  ylab('Proportion precisely measured') +
  geom_point(aes(x=name, y=cm, color=name, shape=always_some_wrong), position=position_jitter(width=0.05)) +
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

#### new plots ###################################################################

new_df = fread('/Users/g/Desktop/new_sim_runs.tsv') %>%
  mutate(critical_exposure = round(critical_exposure, 1),
         exposure_at_activation = round(exposure_at_activation, 1))

# check
new_df %>%
  group_by(name) %>%
  summarize(sum(active) / n())

new_df %>%
  group_by(name, critical_exposure) %>%
  summarize(n())

# plot dfs

crit_df = new_df %>%
  group_by(name) %>%
  mutate(total_nodes = n()) %>%
  ungroup() %>%
  filter(active==1, !is.na(critical_exposure)) %>%
  mutate(exposure = ifelse(critical_exposure > 10, 10, critical_exposure)) %>%
  select(exposure, name, total_nodes) %>%
  group_by(exposure, name) %>%
  summarize(prob = n() / mean(total_nodes),
            kind = 'True') %>%
  group_by(name) %>%
  arrange(name, exposure) %>%
  mutate(cum_prob = cumsum(prob))

eaa_df = new_df %>%
  group_by(name) %>%
  mutate(total_nodes = n()) %>%
  ungroup() %>%
  filter(active==1, !is.na(critical_exposure)) %>%
  mutate(exposure = ifelse(exposure_at_activation > 10, 10, exposure_at_activation)) %>%
  select(exposure, name, total_nodes) %>%
  group_by(exposure, name) %>%
  summarize(prob = n() / mean(total_nodes),
            kind = 'EAA') %>%
    group_by(name) %>%
  arrange(name, exposure) %>%
  mutate(cum_prob = cumsum(prob))

plot_df = rbind(crit_df, eaa_df)

plot_pdf = function(plot_df,
                    graph_name,
                    title,
                    legend=FALSE) {
  plot_df = plot_df %>%
    filter(name == graph_name)
  # frational
  if (graph_name %in% c('th_frac_norm', 'th_frac_exp', 'th_frac_unif', 'th_frac_cons')) {
    p = ggplot(data=plot_df) +
      theme_bw() +
      theme(panel.grid.major = element_blank(),
            panel.grid.minor = element_blank()) +
      labs(y=expression(p(k[i])), x=expression(k[i]), title=element_blank()) + 
      scale_y_continuous(limits=c(0.00, 0.4)) +
      scale_x_continuous(limits=c(0, 1),
                         breaks=c(0,.2,.4,.6,.8,1)) + 
      guides(color=FALSE) +
      geom_line(aes(x=exposure, y=prob, color=kind))
  # non-fractional
  } else {
    p = ggplot(data=plot_df) +
      theme_bw() +
      theme(panel.grid.major = element_blank(),
            panel.grid.minor = element_blank()) +
      labs(y=expression(p(k[i])), x=expression(k[i]), title=element_blank()) + 
      scale_y_continuous(limits=c(0.00, 0.4)) +
      scale_x_continuous(limits=c(0, 10),
                         breaks=c(0,2,4,6,8,10)) + 
      guides(color=FALSE) +
      geom_line(aes(x=exposure, y=prob, color=kind))
  }
  # add legend
  if (legend == TRUE) {
    p = p +
      theme(axis.ticks = element_blank(),
            panel.grid.major = element_blank(),
            panel.grid.minor = element_blank(),
            legend.position = c(0.44, 0.99),
            legend.justification = c("right", "top"),
            legend.box.just = "right",
            legend.margin = margin(6, 6, 6, 6)) +
      guides(color=guide_legend(title=element_blank()))
  }
  return(p)
}

pdf_p1 = plot_pdf(plot_df, 'icm_push', 'ICM "push" model', legend=TRUE)
pdf_p2 = plot_pdf(plot_df, 'icm_pull', 'ICM "pull" model')
pdf_p3 = plot_pdf(plot_df, 'th_int_norm', 'Integer, normal')
pdf_p4 = plot_pdf(plot_df, 'th_int_exp', 'Integer, exponential')
pdf_p5 = plot_pdf(plot_df, 'th_int_unif', 'Integer, uniform')
pdf_p6 = plot_pdf(plot_df, 'th_frac_norm', 'Fractional, normal')
pdf_p7 = plot_pdf(plot_df, 'th_frac_exp', 'Fractional, exponential')
pdf_p8 = plot_pdf(plot_df, 'th_frac_unif', 'Fractional, uniform')
pdf_p9 = plot_df %>%
  filter(name == 'th_frac_cons', kind == 'EAA') %>%
  ggplot(data=.) +
  theme_bw() +
  theme(panel.grid.major = element_blank(),
        panel.grid.minor = element_blank()) +
  labs(y=expression(p(k[i])), x=expression(k[i]), title=element_blank()) + 
  scale_y_continuous(limits=c(0.00, 0.4)) +
  scale_x_continuous(limits=c(0, 1),
                     breaks=c(0,.2,.4,.6,.8,1)) + 
  guides(color=FALSE) +
  geom_line(aes(x=exposure, y=prob, color='EAA')) +
  geom_vline(aes(xintercept=0.2, color='True'), linetype='dashed')

multiplot(pdf_p1, pdf_p3, pdf_p7, pdf_p2,  pdf_p4,  pdf_p9, cols=2)









plot_cdf = function(plot_df,
                    graph_name,
                    title,
                    legend=FALSE) {
  plot_df = plot_df %>%
    filter(name == graph_name)
  if (graph_name %in% c('th_frac_norm', 'th_frac_exp', 'th_frac_unif', 'th_frac_cons')) {
    p = ggplot(data=plot_df) +
      theme_bw() +
      theme(axis.ticks = element_blank(),
            panel.grid.major = element_blank(),
            panel.grid.minor = element_blank()) +
      labs(x=element_blank(), y=element_blank(), title=element_blank()) + 
      scale_y_continuous(limits=c(0.00, 1.00)) +
      scale_x_continuous(limits=c(0, 1),
                         breaks=c(0,.2,.4,.6,.8,1)) + 
      guides(color=FALSE) +
      geom_line(aes(x=exposure, y=cum_prob, color=kind)) +
      geom_line(aes(x=exposure, y=cum_prob, color=kind))
  } else {
    p = ggplot(data=plot_df) +
      theme_bw() +
      theme(axis.ticks = element_blank(),
            panel.grid.major = element_blank(),
            panel.grid.minor = element_blank()) +
      labs(x=element_blank(), y=element_blank(), title=element_blank()) + 
      scale_y_continuous(limits=c(0.00, 1.00)) +
      scale_x_continuous(limits=c(0, 10),
                         breaks=c(0,2,4,6,8,10)) + 
      guides(color=FALSE) +
      geom_line(aes(x=exposure, y=cum_prob, color=kind)) +
      geom_line(aes(x=exposure, y=cum_prob, color=kind))
  }
  if (legend == TRUE) {
    p = ggplot(data=plot_df) +
      theme_bw() +
      theme(axis.ticks = element_blank(),
            panel.grid.major = element_blank(),
            panel.grid.minor = element_blank(),
            legend.position = c(.48, .98),
            legend.justification = c("right", "top"),
            legend.box.just = "right",
            legend.margin = margin(6, 6, 6, 6)) +
      labs(x=element_blank(), y=element_blank(), title=element_blank()) + 
      scale_y_continuous(limits=c(0.00, 1.00)) +
      scale_x_continuous(limits=c(0, 10),
                         breaks=c(0,2,4,6,8,10)) + 
      geom_line(aes(x=exposure, y=cum_prob, color=kind)) +
      geom_line(aes(x=exposure, y=cum_prob, color=kind)) +
      guides(color=guide_legend(title=element_blank()))
  }
  return(p)
}

cdf_p1 = plot_cdf(plot_df, 'icm_push', 'ICM "push" model')
cdf_p2 = plot_cdf(plot_df, 'icm_pull', 'ICM "pull" model')
cdf_p3 = plot_cdf(plot_df, 'th_int_norm', 'Integer, normal', legend=TRUE)
cdf_p4 = plot_cdf(plot_df, 'th_int_exp', 'Integer, exponential')
cdf_p5 = plot_cdf(plot_df, 'th_int_unif', 'Integer, uniform')
cdf_p6 = plot_cdf(plot_df, 'th_frac_norm', 'Fractional, normal')
cdf_p7 = plot_cdf(plot_df, 'th_frac_exp', 'Fractional, exponential')
cdf_p8 = plot_cdf(plot_df, 'th_frac_unif', 'Fractional, uniform')

multiplot(cdf_p1, cdf_p2, cdf_p3, cdf_p4, cdf_p7, cdf_p8, cols=2)
