create table if not exists Hashtags (
    hashtag varchar(140),
    count bigint
);

create table if not exists SuccessTweets (
    uid bigint,
    tid varchar(22),
    raw_text text,
    created_at timestamp,
    hashtag varchar(140)
);

create index succtwt_htag_idx on SuccessTweets (hashtag);

create table if not exists NeighborTags (
  uid bigint,
  tid varchar(22),
  created_at timestamp,
  hashtag varchar(140)
);

create index nbrtag_htag_idx on NeighborTags (hashtag);

create table if not exists Edges(
    src bigint,
    dst bigint
);
