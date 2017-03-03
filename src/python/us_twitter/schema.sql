create table if not exists Hashtags (
    hashtag varchar(140),
    count bigint
);

create table if not exists SuccessTweets (
    uid bigint,
    tid varchar(22),
    raw_text varchar(160),
    created_at timestamp,
    hashtag varchar(140)
);

create table if not exists NeighborTweets (
  uid bigint,
  tid varchar(22),
  raw_text varchar(160),
  created_at timestamp,
  hashtag varchar(140)
);

create table if not exists Edges(
    src bigint,
    dst bigint
);
