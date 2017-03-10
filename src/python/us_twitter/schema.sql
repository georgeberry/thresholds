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

create table if not exists NeighborTags (
  uid bigint not null,
  tid varchar(22) not null,
  created_at timestamp not null,
  hashtag varchar(140) not null,
  constraint nbr_constraint unique (uid, hashtag)
);

create table if not exists Edges(
    src bigint,
    dst bigint
);
