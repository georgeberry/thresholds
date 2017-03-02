create table if not exists Hashtags (
    hashtag varchar(140),
    count bigint
);

create table if not exists SuccessTweets (
    uid varchar(64),
    tid varchar(64),
    raw_text text,
    created_at timestamp,
    hashtags jsonb -- binary json, contains array
);

create table if not exists NeighborTweets (
    uid varchar(64),
    tid varchar(64),
    raw_text text,
    created_at timestamp,
    hashtag varchar(140) -- binary json, contains array
);

-- src->dst ==> dst-src
create table if not exists Edges(
    src varchar(64),
    dst varchar(64)
);
