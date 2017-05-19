library(data.table)
library(ggplot2)
library(dplyr)

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

#### Aggregated ################################################################

df_agg = fread('/Users/g/Desktop/test2.tsv', sep='\t', header=FALSE)
colnames(df_agg) = c('in_interval', 'exposure', 'count')

# Exposure <= 20, get the proportion measured correctly
df_agg_one = df_agg %>%
  group_by(exposure) %>%
  mutate(total = sum(count)) %>%
  ungroup() %>%
  filter(in_interval == 1) %>%
  mutate(ratio = count / total) %>%
  filter(1 <= exposure, exposure <= 20)

# entire CM rate
cm_rate = df_agg_one %>%
  summarize(sum(count) / sum(total))

# plot of raw counts at each exposure
pt1 = df_agg_one %>%
  ggplot(.) +
    theme_bw() +
    theme(panel.grid.major = element_blank(),
          panel.grid.minor = element_blank()) +
    scale_x_continuous(breaks = seq(1,20)) +
    labs(title = 'Total vs correctly measured') +
    geom_line(aes(x=exposure, y=total, color='total')) +
    geom_line(aes(x=exposure, y=count, color='cm'))

ggsave('/Users/g/Desktop/pt1.pdf', pt1, device='pdf', width=8, height = 6)

# plot of ratios at each count
pt2 = df_agg_one %>%
  ggplot(.) +
    theme_bw() +
    theme(panel.grid.major = element_blank(),
          panel.grid.minor = element_blank()) +
    scale_x_continuous(breaks = seq(1,20)) +
    labs(title = 'Mismeasurement rates by exposure') +
    geom_hline(yintercept=0, linetype="dashed") +
    geom_line(aes(x = exposure, y = 1 - ratio)) +
    lims(y=c(0,1))

ggsave('/Users/g/Desktop/pt2.pdf', pt2, device='pdf', width=8, height = 6)

#### Disaggregated #############################################################

df_disagg = fread('/Users/g/Desktop/test1.tsv', sep='\t', header=FALSE)
colnames(df_disagg) = c('in_interval', 'exposure', 'hashtag', 'count')

# measurement rates by tag by exposure
df_disagg_one = df_disagg %>%
  filter(exposure <= 20) %>%
  group_by(exposure, hashtag) %>%
  mutate(total = sum(count)) %>%
  ungroup() %>%
  filter(in_interval == 1) %>%
  mutate(ratio = count / total)

df_mm = df_disagg %>%
  filter(exposure > 0) %>%
  group_by(hashtag) %>%
  mutate(usage_count = sum(count)) %>%
  filter(in_interval == 1) %>%
  summarize(cm_count = sum(count), usage_count = mean(usage_count)) %>%
  mutate(cm_ratio = cm_count / usage_count) %>%
  arrange(-cm_ratio)

summary(lm(cm_ratio ~ log(usage_count), data=df_mm))

df_disagg_one %>%
  filter(exposure <= 7) %>%
  ggplot(.) +
    theme_bw() +
    theme(panel.grid.major = element_blank(),
          panel.grid.minor = element_blank()) +
    scale_x_continuous(breaks = seq(1,7)) +
    lims(y=c(0,1)) +
    geom_line(aes(y=ratio, x=exposure, color=hashtag))

#### Quartiles #################################################################

# repeat p2 with highest and lowest
q = quantile(df_mm$cm_ratio)
q1 = q[2] # top of 25th percentile
q3 = q[4] # bottom of 75th percentile

df_q = df_mm %>%
  mutate(quartile = cut(cm_ratio,
                        breaks=quantile(cm_ratio),
                        include.lowest=TRUE,
                        labels=c('Q1 Mean', 'Q2 Mean', 'Q3 Mean', 'Q4 Mean'))) %>%
  select(hashtag, quartile)

df_net = fread('/Users/g/Desktop/net_stats.tsv', sep='\t')
colnames(df_net) = c('hashtag',
                     'gc_size',
                     'g_size',
                     'one_to_two',
                     'tran',
                     'loc_tran')

df_net_q = df_net %>%
  arrange(-loc_tran) %>%
  mutate(quartile = cut(loc_tran,
                        breaks=quantile(loc_tran),
                        include.lowest=TRUE,
                        labels=c('Clustering Q1 Mean',
                                 'Clustering Q2 Mean',
                                 'Clustering Q3 Mean',
                                 'Clustering Q4 Mean'))) %>%
  select(hashtag, quartile) %>%
  mutate(quartile = factor(quartile, levels = c('Clustering Q4 Mean',
                                                'Clustering Q3 Mean',
                                                'Clustering Q2 Mean',
                                                'Clustering Q1 Mean')))

#### Plot by quartiles #########################################################

df_agg_one$hashtag = 'all'
df_agg_one$quartile = 'Overall Mean'
df_p3 = df_disagg_one %>%
  left_join(df_q, by='hashtag') %>%
  rbind(., df_agg_one) %>%
  group_by(quartile, exposure) %>%
  summarize(count=sum(count),
            total=sum(total),
            ratio=count/total) %>%
  ungroup()

pt3 = df_p3 %>%
  filter(quartile %in% c('Q1 Mean', 'Overall Mean', 'Q4 Mean'), exposure <= 10) %>%
  mutate(quartile = factor(quartile, levels = c('Q4 Mean', 'Overall Mean', 'Q1 Mean'))) %>%
  ggplot(.) +
    theme_bw() +
    theme(panel.grid.major = element_blank(),
          panel.grid.minor = element_blank(),
          legend.position = c(.95, .5),
          legend.justification = c("right", "top"),
          legend.box.just = "right",
          legend.margin = margin(6, 6, 6, 6)) +
    guides(color=guide_legend(title="")) +
    scale_x_continuous(breaks=seq(1,10)) +
    scale_y_continuous(breaks=c(0.00, 0.25, 0.50, 0.60, 0.70, 0.80, 0.90, 1.00),
                       limits=c(0,1)) +
    labs(y='Proportion correctly measured',
         x='Exposure at activation') +
    geom_line(aes(x=exposure, y=ratio, color=quartile)) +
    geom_hline(yintercept=1, linetype="dashed")

ggsave('/Users/g/Desktop/pt3.pdf', pt3, device='pdf', width=5, height=3)

#### first usages ##############################################################

df_fu = fread('/Users/g/Desktop/first_usages.tsv', sep='\t', header=FALSE)
colnames(df_fu) = c('hashtag', 'date', 'count')

# make df

tmp_df = df_fu %>%
  mutate(date = as.numeric(as.POSIXct(date))) %>%
  group_by(hashtag) %>%
  mutate(date = (date - min(date)) / 86400) %>%
  ungroup()

max_date = max(tmp_df$date)

left_df = data.frame()

for (hashtag in unique(tmp_df$hashtag)) {
  new_df = data.frame(hashtag = hashtag,
                      date = seq(0, max_date),
                      count_left = 0)
  left_df = rbind(left_df, new_df)
}

df_fu = left_df %>%
  left_join(tmp_df, by=c('hashtag', 'date')) %>%
  mutate(count = ifelse(!is.na(count), count_left + count, 0)) %>%
  select(hashtag, date, count) %>%
  group_by(hashtag) %>%
    mutate(point_prob = count / sum(count),
         cum_prob = cumsum(count) / sum(count)) %>%
  ungroup()

# plot pdf

pt5 = df_fu %>%
  ggplot(.) +
    geom_line(aes(x=date, y=point_prob, color=hashtag))

ggsave('/Users/g/Desktop/pt5.pdf', p5, device='pdf', width=8, height = 6)

# plot cdf
pt6 = df_fu %>%
  ggplot(.) +
  geom_line(aes(x=date, y=cum_prob, color=hashtag))

ggsave('/Users/g/Desktop/pt6.pdf', p6, device='pdf', width=8, height = 6)

#### gini ######################################################################

library(ineq)

gini_df = df_fu %>%
  group_by(hashtag) %>%
  summarize(gini=ineq(count, type='Gini')) %>%
  arrange(-gini) %>%
  mutate(quartile = cut(gini,
                        breaks=quantile(gini),
                        include.lowest=TRUE,
                        labels=c('Q1', 'Q2', 'Q3', 'Q4'))) %>%
  select(hashtag, quartile)

write.table(gini_df, file='/Users/g/Desktop/gini.tsv', sep="\t")

#### Pk Curves #################################################################

df_pk = fread('/Users/g/Desktop/pk_curves.tsv', sep='\t', header=FALSE)
colnames(df_pk) = c('hashtag',
                    'exposure',
                    'cum_max_exposed',
                    'max_adopters',
                    'cum_min_exposed',
                    'min_adopters')
df_pk = df_pk %>%
  group_by(hashtag, exposure) %>%
  mutate(max_prob = sum(max_adopters) / sum(cum_max_exposed),
         min_prob = sum(min_adopters) / sum(cum_min_exposed)) %>%
  ungroup()

# subtract
df_exp_one = df_pk %>%
  filter(exposure == 1) %>%
  mutate(min_prob_one = min_prob) %>%
  select(hashtag, min_prob_one)

df_exp_two = df_pk %>%
  filter(exposure == 2) %>%
  mutate(min_prob_two = min_prob) %>%
  select(hashtag, min_prob_two)

df_dip = df_exp_one %>%
  left_join(df_exp_two, by='hashtag') %>%
  mutate(dip = ifelse(min_prob_one - min_prob_two > 0, 'Dip', 'No dip')) %>%
  select(hashtag, dip) %>%
  mutate(dip = factor(dip, levels=c('No dip', 'Dip')))

# condition on dip
pt7 = df_pk %>%
  filter(exposure <= 10) %>%
  left_join(df_dip, by='hashtag') %>%
  group_by(dip, exposure) %>%
  summarize(max_prob = sum(max_adopters) / sum(cum_max_exposed),
            min_prob = sum(min_adopters) / sum(cum_min_exposed)) %>%
  ggplot(.) +
    theme_bw() +
    theme(panel.grid.major = element_blank(),
          panel.grid.minor = element_blank(),
          legend.position = c(.46, .25),
          legend.justification = c("right", "top"),
          legend.box.just = "right",
          legend.box = "horizontal",
          legend.margin = margin(6, 6, 6, 6)) +
    guides(color=guide_legend(title=element_blank()),
           linetype=guide_legend(title=element_blank())) +
    scale_x_continuous(breaks=seq(1,10)) +
    scale_y_continuous(limits=c(0.0010,0.019),
                       breaks=c(0.005, 0.010, 0.015)) +
    scale_linetype_manual(values=c("Max p(k) curve"=1,"Min p(k) curve"=2),
                          labels=c(expression(p[U](k)), expression(p[L](k)))) +
    scale_color_manual(values=c("#00BA38", "#619CFF")) +
    labs(y='p(k)',
         x='Exposure') +
    geom_line(aes(x=exposure, y=max_prob, color=dip, linetype='Max p(k) curve')) +
    geom_line(aes(x=exposure, y=min_prob, color=dip, linetype='Min p(k) curve'))

ggsave('/Users/g/Desktop/pt7.pdf', pt7, device='pdf', width=6, height=4)

# condition on clustering
pt8 = df_pk %>%
  filter(exposure <= 10) %>%
  left_join(df_net_q, by='hashtag') %>%
  group_by(quartile, exposure) %>%
  summarize(max_prob = sum(max_adopters) / sum(cum_max_exposed),
            min_prob = sum(min_adopters) / sum(cum_min_exposed)) %>%
  ungroup() %>%
  filter(quartile %in% c('Clustering Q1 Mean', 'Clustering Q4 Mean')) %>%
  ggplot(.) +
  theme_bw() +
    theme(panel.grid.major = element_blank(),
          panel.grid.minor = element_blank(),
          legend.position = c(.67, .25),
          legend.justification = c("right", "top"),
          legend.box.just = "right",
          legend.box = "horizontal",
          legend.margin = margin(6, 6, 6, 6)) +
    guides(color=guide_legend(title=element_blank()),
           linetype=guide_legend(title=element_blank())) +
    scale_x_continuous(breaks=seq(1,10)) +
    scale_y_continuous(limits=c(0.0010,0.019),
                       breaks=c(0.005, 0.010, 0.015)) +
    scale_linetype_manual(values=c("Max p(k) curve"=1,"Min p(k) curve"=2),
                          labels=c(expression(p[U](k)), expression(p[L](k)))) +
    scale_color_manual(values=c("#00BA38", "#619CFF")) +
    labs(y=expression(p(k)),
         x='Exposure') +
    geom_line(aes(x=exposure, y=max_prob, color=as.character(quartile), linetype='Max p(k) curve')) +
    geom_line(aes(x=exposure, y=min_prob, color=as.character(quartile), linetype='Min p(k) curve'))

ggsave('/Users/g/Desktop/pt8.pdf', pt8, device='pdf', width=6, height=4)

multiplot(pt7, pt8, cols=1)
