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

-- create index succtwt_idx on SuccessTweets (uid, hashtag);
-- create index succtwt_uid_idx on SuccessTweets (uid);
-- cluster verbose SuccessTweets using succtwt_uid_idx;

create table if not exists NeighborTags (
  uid bigint,
  tid varchar(22),
  created_at timestamp,
  hashtag varchar(140)
);esta

-- create index nbrtag_htag_idx on NeighborTags (hashtag);
-- create index nbrtag_uid_idx on NeighborTags (uid);
-- cluster verbose Neighbortags using nbrtag_uid_idx;

create table if not exists Edges(
    src bigint,
    dst bigint
);

-- create index edge_idx on Edges (src);
-- alter table edges add constraint unique (src, dst)
