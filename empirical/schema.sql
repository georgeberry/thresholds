
--------------------------- BEGIN BASIC DATA TABLES ----------------------------

--- These data tables that should not be altered after creation and indexing ---

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
-- cluster verbose SuccessTweets using succtwt_idx;
-- create index succtwt_htag_idx on SuccessTweets (hashtag);

create table if not exists NeighborTags (
  uid bigint,
  tid varchar(22),
  created_at timestamp,
  hashtag varchar(140)
);

-- create index nbrtag_idx on NeighborTags (uid, hashtag);
-- cluster verbose Neighbortags using nbrtag_idx;
-- create index nbrtag_htag_idx on NeighborTags (hashtag);

create table if not exists Edges(
    src bigint,
    dst bigint
);

-- create index src_idx on Edges (src);
-- alter table edges add constraint unique (src, dst);

--------------------------- END OF BASIC DATA TABLES ---------------------------

----------- These data tables can be freely modified and overwritten -----------
