library(ggplot2)
library(AER)

DATA_PATH = "/Users/g/Google Drive/project-thresholds/thresholds/data/coleman/output.csv"

df = read.csv(DATA_PATH)

observed_df = na.omit(df[df$correctly.measured == 1 & df$adoption.date != 99,])

summary(lm(exposure.at.adoption ~ city, data=df))

summary(lm(exposure.at.adoption ~ adoption.date, data=df))

summary(lm(exposure.at.adoption ~ med_sch_yr, data=df))

summary(lm(exposure.at.adoption ~ meetings, data=df))

summary(lm(exposure.at.adoption ~ jours, data=df))

summary(lm(exposure.at.adoption ~ free_time, data=df))

summary(lm(exposure.at.adoption ~ discuss, data=df))

summary(lm(exposure.at.adoption ~ clubs, data=df))

summary(lm(exposure.at.adoption ~ friends, data=df))

summary(lm(exposure.at.adoption ~ community, data=df))

summary(lm(exposure.at.adoption ~ proximity, data=df))

summary(lm(exposure.at.adoption ~ specialty, data=df))

summary(lm(exposure.at.adoption ~ specialty + proximity + community + clubs + jours, data=df))

summary(lm(adoption.date ~ jours + clubs + factor(med_sch_yr), data=df))

ggplot(observed_df, aes(x=exposure.at.adoption)) + geom_histogram()
ggplot(df) + geom_histogram(aes(x=exposure.at.adoption, fill=factor(correctly.measured)))

ggplot(df) + geom_histogram(aes(x = activation.delay, fill=factor(correctly.measured)))
