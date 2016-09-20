library(ggplot2)
library(dplyr)

# x is exposure
# y is a binary function of x indicating activity
# we add an upward bias to only the x's for which y is 1
x = sample(1:9, 1000, replace=T)
y = ifelse(x * 0.1 > runif(1000), 1, 0)
summary(lm(y ~ x))

df = data.frame(y = y, x = x)
p = df %>%
  group_by(x) %>%
  summarize(prob = mean(y)) %>%
  ggplot(aes(y=prob, x=x)) + geom_line() + geom_smooth(method="lm")
plot(p)

x.prime = x + ifelse(y == 1, sample(10, 1000, replace=T), 0)
df$x.prime = x.prime
p2 = df %>%
  group_by(x.prime) %>%
  summarize(prob = mean(y)) %>%
  ggplot(aes(y=prob, x=x.prime)) + geom_line() + geom_smooth(method="lm")
plot(p2)

summary(lm(y ~ x, data=df))
summary(lm(y ~ x.prime, data=df))
