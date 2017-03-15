-- We have large tables. Partitions on hashtags will probably be ineffective
-- because there are just too many of them.

create table if not exists Hashtags (
    hashtag varchar(140),
    count bigint
);

-- create index htag_idx on Hashtags (hashtag);

create table if not exists SuccessTweets (
    uid bigint,
    tid varchar(22),
    raw_text text,
    created_at timestamp,
    hashtag varchar(140)
);

-- create index succtwt_htag_idx on SuccessTweets (hashtag);

create table if not exists NeighborTags (
  uid bigint,
  tid varchar(22),
  created_at timestamp,
  hashtag varchar(140)
);

-- create index nbrtag_htag_idx on NeighborTags (hashtag);

create table if not exists Edges(
    src bigint,
    dst bigint,
    UNIQUE (src, dst)
);

-- create index edge_idx on Edges (src);
