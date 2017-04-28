--------------------------- BEGIN BASIC DATA TABLES ---------------------------

create table if not exists Edges (
  src bigint,
  dst bigint
);
-- create index edge_idx on Tweets (src, dst);

create table if not exists Tweets (
  src bigint,
  tid varchar(20),
  created_at timestamp,
  tweet_text text,
  hashtag varchar(140)
);
-- create index twt_idx on Tweets (src, hashtag);
-- create index twt_htag_idx on Tweets hashtag;

--------------------------- BEGIN DERIVED TABLES -------------------------------
